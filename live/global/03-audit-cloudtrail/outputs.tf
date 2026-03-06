output "trail_arn" {
  value       = aws_cloudtrail.this.arn
  description = "CloudTrail trail ARN."
}

output "cloudtrail_bucket" {
  value = {
    name = aws_s3_bucket.cloudtrail.bucket
    arn  = aws_s3_bucket.cloudtrail.arn
  }
  description = "CloudTrail log bucket name and ARN."
}

output "cloudtrail_kms_key" {
  value = {
    arn   = aws_kms_key.cloudtrail.arn
    alias = aws_kms_alias.cloudtrail.name
  }
  description = "KMS key used for CloudTrail log encryption."
}

output "cloudwatch_log_group_name" {
  value       = var.enable_cloudwatch_logs_delivery ? aws_cloudwatch_log_group.cloudtrail[0].name : null
  description = "CloudWatch log group name if enabled."
}
