locals {
  secrets = { for secret in var.custom_secrets : secret.secret_name => secret }

  full_names = {
    for name, secret in local.secrets : name => "${var.secret_name_prefix}${name}${var.secret_name_suffix}"
  }

  # The ListSecrets name filter accepts at most 10 values, so the lookup is
  # split into chunks of 10 names.
  full_name_chunks = chunklist(sort(values(local.full_names)), 10)

  # The name filter is a prefix match, so intersect exactly with our names.
  listed_names = toset(flatten([for listing in data.aws_secretsmanager_secrets.existing : listing.names]))
  existing     = { for name, full_name in local.full_names : name => full_name if contains(local.listed_names, full_name) }

  # Random secrets that already exist and have no explicit version keep their
  # current value: it is read from AWS and written back unchanged.
  kept = {
    for name, secret in local.secrets : name => local.existing[name]
    if !secret.manual && secret.version == null && contains(keys(local.existing), name)
  }
}

data "aws_secretsmanager_secrets" "existing" {
  count = length(local.full_name_chunks)

  filter {
    name   = "name"
    values = local.full_name_chunks[count.index]
  }
}

ephemeral "random_password" "generated" {
  for_each = { for name, secret in local.secrets : name => secret if !secret.manual }

  length           = each.value.length
  special          = each.value.special
  override_special = each.value.override_special
}

ephemeral "aws_secretsmanager_secret_version" "current" {
  for_each = local.kept

  secret_id = each.value
}

resource "aws_secretsmanager_secret" "secret" {
  for_each                = local.secrets
  name                    = local.full_names[each.key]
  recovery_window_in_days = 0
  tags                    = merge(var.tags, each.value.tags)
}

resource "aws_secretsmanager_secret_version" "version" {
  for_each = local.secrets

  secret_id = aws_secretsmanager_secret.secret[each.key].id

  # The value is write-only: it is sent to AWS but never stored in plan or state.
  # - manual: the configured value, or "editme".
  # - random, exists in AWS, no version: the current value, written back unchanged.
  # - random, new or with a version: a freshly generated value.
  secret_string_wo = (
    each.value.manual ? coalesce(each.value.value, "editme") :
    contains(keys(local.kept), each.key) ? ephemeral.aws_secretsmanager_secret_version.current[each.key].secret_string :
    ephemeral.random_password.generated[each.key].result
  )

  # A new value is only written when this number changes.
  # - manual: derived from the value, so changing the value writes a new version.
  # - random: the configured version, 1 when omitted.
  secret_string_wo_version = (
    each.value.manual ?
    parseint(substr(sha256("${coalesce(each.value.value, "editme")}|${coalesce(each.value.version, 0)}"), 0, 7), 16) :
    coalesce(each.value.version, 1)
  )
}
