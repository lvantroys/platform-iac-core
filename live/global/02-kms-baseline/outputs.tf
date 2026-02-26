output "kms_key_arns" {
  description = "KMS key ARNs for platform baseline keys."
  value = {
    logs    = aws_kms_key.logs.arn
    secrets = aws_kms_key.secrets.arn
    ssm     = aws_kms_key.ssm.arn
    ebs     = aws_kms_key.ebs.arn
  }
}

output "kms_aliases" {
  description = "KMS aliases for platform baseline keys."
  value       = local.aliases
}
