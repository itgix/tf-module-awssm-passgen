
# Terraform AWS Secrets Password Module

This Terraform module creates and manages secrets in AWS Secrets Manager, with support for custom lengths, special characters, and dynamic regeneration based on specified keepers.

## Usage

To use this module in your Terraform configuration, follow the steps below:

### Basic Usage

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
    },
    {
      secret_name = "secretForManualEdit"
      manual      = true
    }
  ]

  secret_name_prefix = "dev-"
  secret_name_suffix = "-prod"
  secret_keepers = {
    "mySecret" = {
      "ami_id" = "ami-12345678"
    }
  }

  tags = {
    "Environment" = "dev"
    "ManagedBy"   = "terraform"
  }
}
```

## Outputs

You can access the following outputs:

- `module.secrets-password-module.secret_arns`: ARNs of the created secrets.
- `module.secrets-password-module.secret_names`: Names of the created secrets.
- `module.secrets-password-module.secret_versions`: Version IDs of the created secrets.
- `module.secrets-password-module.secret_values`: The values of the created secrets (sensitive information).

## Variables

- `custom_secrets`: A list of custom secrets to create. Each secret object can have the following attributes:
  - `secret_name`: Name of the secret (required).
  - `length`: Length of the secret (required).
  - `special`: Boolean flag to include special characters (optional).
  - `override_special`: Custom string of special characters to use (optional).
  - `keepers`: A map of key-value pairs used for dynamic regeneration (optional).
  - `tags`: A map of tags to apply to this specific secret. Merged with the module-wide `tags`, taking precedence on key conflicts (optional).
- `secret_name_prefix`: Prefix for secret names (optional).
- `secret_name_suffix`: Suffix for secret names (optional).
- `secret_keepers`: Map of keepers for the secrets (optional).
- `tags`: Map of tags applied to all created secrets. Merged with per-secret `tags` (optional).

## Notes

- Secrets and their values are stored in the Terraform state file. Handle this file securely.
- The `secret_values` output is marked as sensitive and will not be displayed in the console.
