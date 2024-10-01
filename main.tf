resource "random_password" "password" {
  for_each         = { for secret in var.custom_secrets : secret.secret_name => secret if !lookup(secret, "empty", false) }
  length           = each.value.length
  special          = lookup(each.value, "special", false)
  override_special = lookup(each.value, "override_special", null)
  keepers          = lookup(var.secret_keepers, each.key, {})
}

resource "aws_secretsmanager_secret" "secret" {
  for_each = { for secret in var.custom_secrets : secret.secret_name => secret }
  name     = "${var.secret_name_prefix}${each.value.secret_name}${var.secret_name_suffix}"
}

# Resource for non-empty secrets, which generates a random password
resource "aws_secretsmanager_secret_version" "version_non_empty" {
  for_each = { for secret in var.custom_secrets : secret.secret_name => secret if !lookup(secret, "empty", false) }

  secret_id     = aws_secretsmanager_secret.secret[each.key].id
  secret_string = random_password.password[each.key].result
}

# Resource for empty secrets, ensuring Terraform doesn't overwrite manual changes
resource "aws_secretsmanager_secret_version" "version_empty" {
  for_each = { for secret in var.custom_secrets : secret.secret_name => secret if lookup(secret, "empty", false) }

  secret_id     = aws_secretsmanager_secret.secret[each.key].id
  secret_string = ""

  lifecycle {
    ignore_changes = [
      secret_string
    ]
  }
}
