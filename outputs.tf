output "secret_arns" {
  description = "ARNs of the created secrets in AWS Secrets Manager."
  value       = { for secret in var.custom_secrets : secret.secret_name => aws_secretsmanager_secret.secret[secret.secret_name].arn }
}

output "secret_names" {
  description = "Names of the created secrets in AWS Secrets Manager."
  value       = { for secret in var.custom_secrets : secret.secret_name => aws_secretsmanager_secret.secret[secret.secret_name].name }
}

# Include both version resources (non-empty and empty)
output "secret_versions" {
  description = "The versions of the created secrets in AWS Secrets Manager."
  value       = merge(
    { for key, version in aws_secretsmanager_secret_version.version_non_empty : key => version.version_id },
    { for key, version in aws_secretsmanager_secret_version.version_empty : key => version.version_id }
  )
}

# Output only for non-empty secrets where passwords were generated
output "secret_values" {
  description = "The values of the created secrets. Sensitive information."
  value       = { for key, value in random_password.password : key => value.result }
  sensitive   = true
}
