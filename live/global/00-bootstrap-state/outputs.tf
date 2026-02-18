output "state_bucket_name" {
  description = "Terraform state bucket name."
  value       = aws_s3_bucket.tfstate.id
}

output "state_bucket_arn" {
  description = "Terraform state bucket ARN."
  value       = aws_s3_bucket.tfstate.arn
}

output "state_kms_key_arn" {
  description = "KMS key ARN used for state encryption."
  value       = aws_kms_key.tfstate.arn
}

output "state_kms_key_alias" {
  description = "KMS key alias."
  value       = aws_kms_alias.tfstate.name
}

output "backend_config_recommended" {
  description = "Recommended backend settings for this stack and downstream stacks."
  value = {
    bucket       = aws_s3_bucket.tfstate.id
    key          = var.bootstrap_state_key
    region       = data.aws_region.current.name
    encrypt      = true
    kms_key_id   = aws_kms_key.tfstate.arn
    use_lockfile = true
  }
}
