variable "aws_region" {
  description = "AWS region for this bootstrap stack."
  type        = string
}

variable "assume_role_arn" {
  description = "Optional role ARN for Terraform execution."
  type        = string
  default     = null
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid S3 bucket name (lowercase, 3-63 chars)."
  }
}

variable "bootstrap_state_key" {
  description = "State object key used by this folder after migration."
  type        = string
  default     = "platform-iac-core/global/00-bootstrap-state/terraform.tfstate"
}

variable "kms_alias" {
  description = "Alias name for the Terraform state KMS key."
  type        = string
  default     = "alias/platform/terraform-state"

  validation {
    condition     = startswith(var.kms_alias, "alias/")
    error_message = "kms_alias must start with alias/."
  }
}

variable "kms_key_deletion_window_days" {
  description = "KMS key deletion window in days (7-30)."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window_days >= 7 && var.kms_key_deletion_window_days <= 30
    error_message = "kms_key_deletion_window_days must be between 7 and 30."
  }
}

variable "owner" {
  description = "Resource owner tag value."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner cannot be empty."
  }
}

variable "environment" {
  description = "Environment tag value. For this stack normally 'global'."
  type        = string
  default     = "global"
}

variable "app" {
  description = "App tag value."
  type        = string
  default     = "platform-core"
}

variable "data_classification" {
  description = "Data classification tag."
  type        = string
  default     = "restricted"

  validation {
    condition = contains(
      ["public", "internal", "confidential", "restricted"],
      var.data_classification
    )
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "extra_tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}

variable "kms_admin_principal_arns" {
  description = "IAM principal ARNs allowed to administer the KMS key (not usage-only)."
  type        = list(string)
  default     = []
}

variable "allowed_state_writer_principal_arns" {
  description = "IAM principal ARNs allowed read/write access to the state bucket objects."
  type        = list(string)
  default     = []
}

variable "allowed_state_reader_principal_arns" {
  description = "IAM principal ARNs allowed read-only access to the state bucket objects."
  type        = list(string)
  default     = []
}

variable "enable_object_lock" {
  description = "Enable S3 Object Lock for the state bucket (must be decided at bucket creation time)."
  type        = bool
  default     = false
}

variable "object_lock_mode" {
  description = "Object Lock mode if enabled."
  type        = string
  default     = "GOVERNANCE"

  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "object_lock_mode must be GOVERNANCE or COMPLIANCE."
  }
}

variable "object_lock_days" {
  description = "Default Object Lock retention in days (used only if enabled)."
  type        = number
  default     = 7

  validation {
    condition     = var.object_lock_days >= 1 && var.object_lock_days <= 36500
    error_message = "object_lock_days must be between 1 and 36500."
  }
}

variable "noncurrent_version_transition_days" {
  description = "Days before noncurrent state versions transition to STANDARD_IA."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_transition_days >= 1
    error_message = "noncurrent_version_transition_days must be >= 1."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent versions are deleted. Set 0 to disable deletion."
  type        = number
  default     = 3650

  validation {
    condition     = var.noncurrent_version_expiration_days == 0 || var.noncurrent_version_expiration_days >= 30
    error_message = "noncurrent_version_expiration_days must be 0 or >= 30."
  }
}
