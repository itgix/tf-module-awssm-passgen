terraform {
  # Write-only arguments (secret_string_wo) need Terraform 1.11.
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 6.50.0 is the first release that moves a secret version created with a
      # plain secret_string to secret_string_wo in place when the value is
      # unchanged, instead of replacing it.
      version = ">= 6.50.0"
    }
    random = {
      source = "hashicorp/random"
      # 3.7 adds the ephemeral random_password resource.
      version = ">= 3.7"
    }
  }
}
