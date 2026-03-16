locals {
  prefix_path = trim(var.config_bucket_prefix, "/")
  s3_prefix   = local.prefix_path == "" ? "" : "${local.prefix_path}/"

  # AWS Config delivery path (AWS standard layout includes AWSLogs/<acct>/Config/)
  config_object_prefix = "${local.s3_prefix}AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"

  # A small, safe baseline of AWS managed rules (identifiers are standard AWS managed rules).
  default_managed_rules = {
    cloudtrail_enabled = {
      source_identifier = "CLOUD_TRAIL_ENABLED"
      description       = "CloudTrail must be enabled."
    }
    cloudtrail_log_validation = {
      source_identifier = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED"
      description       = "CloudTrail log file validation must be enabled."
    }
    s3_ssl_only = {
      source_identifier = "S3_BUCKET_SSL_REQUESTS_ONLY"
      description       = "S3 buckets must require SSL."
    }
    s3_sse_enabled = {
      source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
      description       = "S3 buckets must have default encryption enabled."
    }
    s3_public_read = {
      source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
      description       = "S3 buckets must not allow public read."
    }
    s3_public_write = {
      source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
      description       = "S3 buckets must not allow public write."
    }
    required_tags = {
      source_identifier = "REQUIRED_TAGS"
      description       = "Require standard tags on resources."
      input_parameters = {
        tag1Key = "env"
        tag2Key = "app"
        tag3Key = "owner"
        tag4Key = "data-classification"
      }
    }
  }

  effective_managed_rules = (
    var.enable_managed_rules
    ? (length(var.managed_rules) > 0 ? var.managed_rules : local.default_managed_rules)
    : tomap({})
  )

  config_service_linked_role_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig"
}
