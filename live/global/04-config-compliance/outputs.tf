output "config_bucket" {
  description = "AWS Config delivery bucket."
  value = {
    name = aws_s3_bucket.config.bucket
    arn  = aws_s3_bucket.config.arn
  }
}

output "config_kms_key" {
  description = "KMS CMK used to encrypt AWS Config delivered objects."
  value = {
    arn   = aws_kms_key.config.arn
    alias = aws_kms_alias.config.name
  }
}

output "recorder" {
  description = "AWS Config recorder name."
  value       = aws_config_configuration_recorder.this.name
}

output "delivery_channel" {
  description = "AWS Config delivery channel name."
  value       = aws_config_delivery_channel.this.name
}

output "managed_rule_names" {
  description = "Names of managed Config rules created by this stack."
  value       = [for r in aws_config_config_rule.managed : r.name]
}
