# Terraform AWS Secrets Password Module

This Terraform module creates and manages secrets in AWS Secrets Manager. Random secrets are generated
once with a configurable length and character set and then stay static; they are rotated only when
their `version` is set or raised. Manual secrets are created with a placeholder or a given value and
are meant to be edited outside Terraform.

Secret values are written with the AWS provider's write-only argument `secret_string_wo`: they exist
only in AWS Secrets Manager and are never stored in the Terraform state or in plan files.

## Requirements

- Terraform >= 1.11 (write-only arguments)
- hashicorp/aws >= 6.50.0
- hashicorp/random >= 3.7 (ephemeral `random_password`)

## Usage

```hcl
provider "aws" {
  region = "us-west-2"
}

module "secrets-password-module" {
  source = "path/to/secrets-password-module"

  custom_secrets = [
    {
      secret_name      = "mySecret"
      length           = 16
      special          = true
      override_special = "!@#$%^&*"
      tags = {
        "Team" = "platform"
      }
    },
    {
      secret_name = "anotherSecret"
      length      = 20
      version     = 2 # rotated once when raised from 1 (or from omitted) to 2
    },
    {
      secret_name = "secretForManualEdit"
      manual      = true
    }
  ]

  secret_name_prefix = "dev-"
  secret_name_suffix = "-prod"

  tags = {
    "Environment" = "dev"
    "ManagedBy"   = "terraform"
  }
}
```

## Outputs

- `module.secrets-password-module.secret_arns`: ARNs of the created secrets.
- `module.secrets-password-module.secret_names`: Names of the created secrets.
- `module.secrets-password-module.secret_versions`: Version IDs of the secret versions managed by the module.

The module does not output secret values. Consumers read them from AWS Secrets Manager.

## Variables

- `custom_secrets`: A list of secrets to create. Each secret object can have the following attributes:
  - `secret_name`: Name of the secret (required).
  - `length`: Length of a random secret (optional, default `32`).
  - `special`: Include special characters in a random secret (optional, default `false`).
  - `override_special`: Custom string of special characters to use (optional).
  - `manual`: Create the secret with `value` (or the placeholder `editme`) instead of a random value
    (optional, default `false`).
  - `value`: Value of a manual secret (optional). Changing it writes a new secret version.
  - `version`: Rotation counter of a random secret (optional), see below.
  - `tags`: A map of tags to apply to this specific secret. Merged with the module-wide `tags`, taking
    precedence on key conflicts (optional).
- `secret_name_prefix`: Prefix for secret names (optional).
- `secret_name_suffix`: Suffix for secret names (optional).
- `tags`: Map of tags applied to all created secrets. Merged with per-secret `tags` (optional).

### `version` and rotation

- **Omitted:** the secret is static. If it already exists in AWS Secrets Manager its current value is
  kept; if it does not exist, a random value is generated once.
- **Set or raised:** exactly one new secret version with a newly generated value is written on the next
  apply. After that the secret is static again until `version` changes once more.
- **Never lower `version`.** Any change of the number writes a new value; only raise it.
- **Do not set `version` while upgrading from v1.0.x** unless you want that secret rotated in the same
  apply.
- **Manual secrets** ignore rotation: a changed `value` writes a new secret version, an unchanged
  `value` writes nothing. Edits made to a manual secret outside Terraform are left alone.

## Upgrading from v1.0.x

- Raise the version floors: Terraform 1.11, hashicorp/aws 6.50.0, hashicorp/random 3.7.
- The per-secret `keepers` attribute and the `secret_keepers` variable are removed; use `version` to
  rotate a secret.
- The `secret_values` output is removed; read values from AWS Secrets Manager.
- The first plan after the upgrade shows an **in-place update** of each `aws_secretsmanager_secret_version`
  (no replace). The apply writes no new secret version, changes no value, and removes the clear-text
  value from the Terraform state. The same plan shows the old `random_password.password` resources being
  destroyed; that only removes them (and the clear-text values they held) from the state, nothing in AWS
  is deleted. No flag or manual step is needed.
- A **replace** of a secret version in that plan means a `version` was set or a manual `value` changed,
  and that secret will get a new value.

## Notes

- Secret values are never stored in the Terraform state or in plan files. They exist only in AWS Secrets
  Manager.
- At plan time the module calls `ListSecrets` (filtered by the secret names) to find which secrets
  already exist, and `GetSecretValue` on the `AWSCURRENT` stage of each existing random secret without a
  `version`, so the current value can be written back unchanged. The planning identity needs
  `secretsmanager:ListSecrets` and `secretsmanager:GetSecretValue` on those secrets.
- Known edge case: a secret that exists in AWS Secrets Manager but has no `AWSCURRENT` version makes the
  plan fail. Delete that secret or set `version` on it.
