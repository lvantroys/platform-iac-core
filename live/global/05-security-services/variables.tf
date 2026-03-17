variable "aws_region" {
  type        = string
  description = "Region where services are enabled."
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

############################
# GuardDuty
############################
variable "enable_guardduty" {
  type        = bool
  default     = true
  description = "Enable Amazon GuardDuty in this region."
}

variable "guardduty_finding_publishing_frequency" {
  type        = string
  default     = "SIX_HOURS"
  description = "Frequency for GuardDuty findings publishing: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS."
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_publishing_frequency)
    error_message = "guardduty_finding_publishing_frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "configure_guardduty_datasources" {
  type        = bool
  default     = true
  description = "Configure GuardDuty datasources block. Recommended true for consistent baseline."
}

variable "guardduty_enable_s3_protection" {
  type        = bool
  default     = true
  description = "Enable GuardDuty S3 protection (S3 logs)."
}

variable "guardduty_enable_kubernetes_audit_logs" {
  type        = bool
  default     = false
  description = "Enable GuardDuty EKS Kubernetes audit log protection (only if you use EKS)."
}

variable "guardduty_enable_malware_protection_ebs" {
  type        = bool
  default     = true
  description = "Enable GuardDuty malware protection for EC2 EBS volumes for instances with findings."
}

############################
# Security Hub
############################
variable "enable_securityhub" {
  type        = bool
  default     = true
  description = "Enable AWS Security Hub CSPM in this region."
}

variable "securityhub_enable_default_standards" {
  type        = bool
  default     = false
  description = "Whether Security Hub should auto-enable its default standards."
}

variable "securityhub_control_finding_generator" {
  type        = string
  default     = "SECURITY_CONTROL"
  description = "Security Hub control finding generator: SECURITY_CONTROL or STANDARD_CONTROL."
  validation {
    condition     = contains(["SECURITY_CONTROL", "STANDARD_CONTROL"], var.securityhub_control_finding_generator)
    error_message = "securityhub_control_finding_generator must be SECURITY_CONTROL or STANDARD_CONTROL."
  }
}

variable "securityhub_auto_enable_controls" {
  type        = bool
  default     = true
  description = "Automatically enable newly released Security Hub controls."
}

variable "securityhub_standards" {
  type        = list(string)
  description = <<EOT
List of Security Hub standards to enable, expressed as the standards path suffix under /standards/.

Examples:
- aws-foundational-security-best-practices/v/1.0.0
- cis-aws-foundations-benchmark/v/1.4.0
- aws-resource-tagging-standard/v/1.0.0
EOT
  default = [
    "aws-foundational-security-best-practices/v/1.0.0",
    "cis-aws-foundations-benchmark/v/1.4.0",
    "aws-resource-tagging-standard/v/1.0.0"
  ]
}

############################
# IAM Access Analyzer
############################
variable "enable_access_analyzer" {
  type        = bool
  default     = true
  description = "Enable IAM Access Analyzer analyzer in this region."
}

variable "create_accessanalyzer_service_linked_role" {
  type        = bool
  default     = true
  description = "Create the Access Analyzer service-linked role (import if it already exists)."
}

variable "access_analyzer_name" {
  type        = string
  default     = "platform-access-analyzer"
  description = "Name of the IAM Access Analyzer analyzer."
}

variable "access_analyzer_type" {
  type        = string
  default     = "ACCOUNT"
  description = "Analyzer type: ACCOUNT or ORGANIZATION."
  validation {
    condition     = contains(["ACCOUNT", "ORGANIZATION"], var.access_analyzer_type)
    error_message = "access_analyzer_type must be ACCOUNT or ORGANIZATION."
  }
}
