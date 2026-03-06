variable "aws_region" {
  type        = string
  description = "Region where the CloudTrail trail is created (trail ARN uses this region)."
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

# CloudTrail basics
variable "trail_name" {
  type        = string
  description = "CloudTrail name (used to construct SourceArn conditions)."
  default     = "platform-audit"
}

variable "is_multi_region_trail" {
  type        = bool
  default     = true
  description = "Enable multi-region trail."
}

variable "include_global_service_events" {
  type        = bool
  default     = true
  description = "Include global service events in CloudTrail."
}

variable "enable_log_file_validation" {
  type        = bool
  default     = true
  description = "Enable CloudTrail log file validation."
}

variable "s3_key_prefix" {
  type        = string
  default     = "cloudtrail"
  description = "Optional S3 key prefix in the log bucket."
}

# S3 bucket for CloudTrail logs
variable "cloudtrail_bucket_name" {
  type        = string
  description = "Name of the S3 bucket that stores CloudTrail logs."
}

variable "bucket_force_destroy" {
  type        = bool
  default     = false
  description = "Should be false in regulated environments."
}

# Optional object lock (requires bucket to be created with object_lock_enabled)
variable "enable_object_lock" {
  type        = bool
  default     = false
  description = "Enable S3 Object Lock for the CloudTrail bucket (requires versioning)."
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
  description = "Default retention in days when enable_object_lock = true."
}

# KMS principals
variable "kms_admin_principal_arns" {
  type        = list(string)
  description = "Who can administer the CloudTrail KMS key (PutKeyPolicy, rotation, alias, etc.)"
  default     = []
}

variable "kms_log_decrypt_principal_arns" {
  type        = list(string)
  description = "Who can decrypt CloudTrail logs (read access path). Empty is allowed; root retains break-glass."
  default     = []
}

# CloudWatch Logs delivery (optional)
variable "enable_cloudwatch_logs_delivery" {
  type        = bool
  default     = false
  description = "Send CloudTrail events to CloudWatch Logs."
}

variable "cloudwatch_log_group_retention_days" {
  type        = number
  default     = 90
  description = "Retention for CloudWatch Log Group (if enabled)."
}

variable "cloudwatch_logs_kms_key_arn" {
  type        = string
  default     = null
  description = "Optional CMK for the CloudWatch Log Group (recommended)."
}

# Optional S3 data events (can be expensive)
variable "enable_s3_data_events" {
  type        = bool
  default     = false
  description = "Enable S3 data events. Off by default due to cost."
}

variable "s3_data_event_arn_prefixes" {
  type        = list(string)
  default     = []
  description = <<EOT
List of S3 object ARNs or prefixes for data events.
Examples:
- arn:aws:s3:::my-bucket/
- arn:aws:s3:::my-bucket/some/prefix/
EOT
}

# Optional CloudTrail Insights
variable "enable_cloudtrail_insights" {
  type        = bool
  default     = false
  description = "Enable CloudTrail Insights selectors."
}
