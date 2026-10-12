variable "custom_secrets" {
  description = <<-EOT
    List of secrets to create in AWS Secrets Manager.
    A random secret (manual = false) is generated once and stays static; set or raise
    `version` to rotate it. `version` applies to random secrets only and is ignored
    for manual ones. A manual secret is written with `value` (or "editme");
    changing `value` writes a new secret version. `value` applies to manual secrets only.
  EOT
  type = list(object({
    secret_name      = string
    length           = optional(number, 32)
    special          = optional(bool, false)
    override_special = optional(string)
    manual           = optional(bool, false)
    value            = optional(string)
    version          = optional(number)
    tags             = optional(map(string), {})
  }))

  validation {
    condition     = alltrue([for s in var.custom_secrets : s.manual || s.value == null || s.value == ""])
    error_message = "custom_secrets: `value` is only used by manual secrets (manual = true); remove it from random secrets or set manual = true."
  }

  validation {
    condition     = alltrue([for s in var.custom_secrets : s.version == null || (s.version >= 1 && floor(s.version) == s.version)])
    error_message = "custom_secrets: `version` must be a whole number >= 1."
  }
}

variable "tags" {
  description = "Map of tags to apply to all created secrets. Merged with per-secret tags, where per-secret tags take precedence."
  type        = map(string)
  default     = {}
}

variable "secret_name_prefix" {
  description = "Prefix for secret names"
  type        = string
  default     = ""
}

variable "secret_name_suffix" {
  description = "Suffix for secret names"
  type        = string
  default     = ""
}
