resource "random_password" "password" {
  for_each         = { for secret in var.custom_secrets : secret.secret_name => secret }
  length           = each.value.length
  special          = lookup(each.value, "special", false)
  override_special = lookup(each.value, "override_special", null)
  keepers          = lookup(var.secret_keepers, each.key, {})
}

resource "aws_secretsmanager_secret" "secret" {
  for_each = { for secret in var.custom_secrets : secret.secret_name => secret }
  name     = "${var.secret_name_prefix}${each.value.secret_name}${var.secret_name_suffix}"
}

resource "aws_secretsmanager_secret_version" "version" {
  for_each      = { for secret in var.custom_secrets : secret.secret_name => secret }
  secret_id     = aws_secretsmanager_secret.secret[each.key].id
  secret_string = random_password.password[each.key].result
}

