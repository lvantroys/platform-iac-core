variable "aws_region" {
  type        = string
  description = "Region where AWS Config is enabled."
}

variable "assume_role_arn" {
  type        = string
  default     = null
  description = "Optional role ARN to assume (controlled/break-glass)."
}

variable "environment" {
  type        = string
  default     = "global"
  description = "Tag: env"
}

variable "app" {
  type        = string
  default     = "platform-core"
  description = "Tag: app"
}

variable "owner" {
  type        = string
  description = "Tag: owner"
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
  description = "Extra resource tags."
}

# S3 delivery bucket for AWS Config
variable "config_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for AWS Config snapshots/history."
}

variable "config_bucket_prefix" {
  type        = string
  default     = "config"
  description = "Optional key prefix under which AWS Config stores objects."
}

variable "bucket_force_destroy" {
  type        = bool
  default     = false
  description = "Should be false in regulated environments."
}

# Optional Object Lock (must be enabled at bucket creation time)
variable "enable_object_lock" {
  type        = bool
  default     = false
  description = "Enable S3 Object Lock for the AWS Config bucket."
}

variable "object_lock_mode" {
  type        = string
  default     = "GOVERNANCE"
  description = "GOVERNANCE or COMPLIANCE"
  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "object_lock_mode must be GOV/COMPLIANCE."
  }
}

variable "object_lock_days" {
  type        = number
  default     = 7
  description = "Default object retention days when enable_object_lock = true."
}

# KMS principals
variable "kms_admin_principal_arns" {
  type        = list(string)
  default     = []
  description = "Principals allowed to administer the AWS Config CMK."
}

variable "kms_decrypt_principal_arns" {
  type        = list(string)
  default     = []
  description = "Principals allowed to decrypt AWS Config delivered objects (for investigations)."
}

# AWS Config recorder settings
variable "recorder_name" {
  type        = string
  default     = "default"
  description = "AWS Config configuration recorder name."
}

variable "record_all_supported" {
  type        = bool
  default     = true
  description = "Record all supported resource types."
}

variable "include_global_resource_types" {
  type        = bool
  default     = true
  description = "Include global resource types (IAM, etc.)."
}

variable "config_retention_days" {
  type        = number
  default     = 365
  description = "Retention for AWS Config configuration items."
}

# Delivery channel settings
variable "delivery_channel_name" {
  type        = string
  default     = "default"
  description = "Delivery channel name."
}

variable "snapshot_delivery_frequency" {
  type        = string
  default     = "TwentyFour_Hours"
  description = "AWS Config snapshot delivery frequency (e.g., One_Hour, Three_Hours, Six_Hours, Twelve_Hours, TwentyFour_Hours)."
}

# Optional managed rules baseline
variable "enable_managed_rules" {
  type        = bool
  default     = true
  description = "Enable a baseline set of AWS managed Config rules."
}

variable "managed_rules" {
  type = map(object({
    source_identifier           = string
    description                 = optional(string)
    input_parameters            = optional(map(string))
    maximum_execution_frequency = optional(string)
  }))
  default     = {}
  description = "Map of rule_name => rule config. If empty and enable_managed_rules=true, defaults are used in locals."
}
