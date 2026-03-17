output "guardduty_detector_id" {
  description = "GuardDuty detector ID (if enabled)."
  value       = var.enable_guardduty ? aws_guardduty_detector.this[0].id : null
}

output "securityhub_hub_arn" {
  description = "Security Hub hub ARN (if enabled)."
  value       = var.enable_securityhub ? aws_securityhub_account.this[0].arn : null
}

output "securityhub_enabled_standards_arns" {
  description = "Standards ARNs enabled via Terraform (if Security Hub enabled)."
  value       = var.enable_securityhub ? tolist(local.securityhub_standards_arns) : []
}

output "access_analyzer_arn" {
  description = "Access Analyzer ARN (if enabled)."
  value       = var.enable_access_analyzer ? aws_accessanalyzer_analyzer.this[0].arn : null
}
