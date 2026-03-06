locals {

  # CloudTrail ARN is deterministic from trail name + region + account
  trail_arn = "arn:${data.aws_partition.current.partition}:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"

  # Normalize prefix for policy paths
  prefix_path = trim(var.s3_key_prefix, "/")
  s3_prefix   = local.prefix_path == "" ? "" : "${local.prefix_path}/"

  # Where CloudTrail writes logs (per AWS doc)
  cloudtrail_object_prefix = "${local.s3_prefix}AWSLogs/${data.aws_caller_identity.current.account_id}/*"
}
