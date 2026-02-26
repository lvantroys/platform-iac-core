variable "aws_region" {
  type        = string
  description = "AWS region for KMS keys."
}

variable "assume_role_arn" {
  type        = string
  default     = null
  description = "Optional role ARN to assume (break-glass / controlled)."
}

variable "owner" {
  type        = string
  description = "Tag: owner"
}

variable "environment" {
  type        = string
  default     = "global"
  description = "Tag: environment for this stack."
}

variable "app" {
  type        = string
  default     = "platform-core"
  description = "Tag: app"
}

variable "data_classification" {
  type        = string
  default     = "restricted"
  description = "Tag: data-classification"
  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "extra_tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags."
}

# Key policy principals
variable "kms_admin_principal_arns" {
  type        = list(string)
  description = "Principals allowed to administer keys (policy updates, grants, rotation, aliases)."
  default     = []
}

variable "kms_usage_principal_arns" {
  type        = list(string)
  description = "Principals allowed to use keys (Encrypt/Decrypt/DataKey). Typically CI roles and runtime roles."
  default     = []
}

# Optional service restrictions
variable "enable_viaservice_conditions" {
  type        = bool
  default     = true
  description = "When true, key usage is restricted with kms:ViaService for common AWS services where applicable."
}

# EBS encryption-by-default
variable "enable_ebs_encryption_by_default" {
  type        = bool
  default     = true
  description = "Enable EBS encryption by default in this region."
}
