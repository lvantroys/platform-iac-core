########################################
# S3 bucket for CloudTrail logs
########################################

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = var.cloudtrail_bucket_name
  force_destroy = var.bucket_force_destroy

  # Required if you want Object Lock.
  object_lock_enabled = var.enable_object_lock

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.cloudtrail.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "abort-incomplete-mpu"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "cloudtrail" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    default_retention {
      mode = var.object_lock_mode
      days = var.object_lock_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.cloudtrail]
}

########################################
# KMS key for CloudTrail logs (dedicated)
########################################

data "aws_iam_policy_document" "cloudtrail_kms" {
  # Break-glass root control to avoid lockout.
  statement {
    sid    = "AllowRootAccountFullAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Key administrators (policy/rotation/alias/grants/etc.)
  dynamic "statement" {
    for_each = length(var.kms_admin_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowKeyAdministrators"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = compact(var.kms_admin_principal_arns)
      }
      actions = [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
        "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
        "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
      ]
      resources = ["*"]
    }
  }

  # Required: Allow CloudTrail to encrypt logs (GenerateDataKey*) with SourceArn + EncryptionContext.
  # Matches AWS documentation for trails. :contentReference[oaicite:3]{index=3}
  statement {
    sid    = "AllowCloudTrailEncryptLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"]
    }
  }

  # Required example: allow CloudTrail to decrypt trail logs (AWS shows a service-principal decrypt statement). :contentReference[oaicite:4]{index=4}
  statement {
    sid    = "AllowCloudTrailDecryptTrail"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  # Required: allow CloudTrail to describe the key (AWS recommended statement with SourceArn). :contentReference[oaicite:5]{index=5}
  statement {
    sid    = "AllowCloudTrailDescribeKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["kms:DescribeKey"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  # Optional: allow specific principals to decrypt CloudTrail logs (for reading).
  # Follows AWS example using EncryptionContext presence check. :contentReference[oaicite:6]{index=6}
  dynamic "statement" {
    for_each = length(compact(var.kms_log_decrypt_principal_arns)) > 0 ? [1] : []
    content {
      sid    = "AllowPrincipalsDecryptCloudTrailLogs"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = compact(var.kms_log_decrypt_principal_arns)
      }
      actions   = ["kms:Decrypt"]
      resources = ["*"]
      condition {
        test     = "Null"
        variable = "kms:EncryptionContext:aws:cloudtrail:arn"
        values   = ["false"]
      }
    }
  }
}

resource "aws_kms_key" "cloudtrail" {
  description             = "CMK for CloudTrail log encryption (S3 SSE-KMS)"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.cloudtrail_kms.json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "cloudtrail" {
  name          = "alias/platform/cloudtrail"
  target_key_id = aws_kms_key.cloudtrail.key_id
}

########################################
# S3 bucket policy allowing CloudTrail writes
########################################

data "aws_iam_policy_document" "cloudtrail_bucket" {
  # Allow CloudTrail to check bucket ACL (AWS required pattern). :contentReference[oaicite:7]{index=7}
  statement {
    sid     = "AWSCloudTrailAclCheck20150319"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    resources = [aws_s3_bucket.cloudtrail.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  # Allow CloudTrail to write logs (AWS required pattern with bucket-owner-full-control). :contentReference[oaicite:8]{index=8}
  statement {
    sid     = "AWSCloudTrailWrite20150319"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.cloudtrail.arn}/${local.cloudtrail_object_prefix}"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  # Defense-in-depth: deny insecure transport
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      aws_s3_bucket.cloudtrail.arn,
      "${aws_s3_bucket.cloudtrail.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

########################################
# Optional: CloudWatch Logs delivery
########################################

resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = var.enable_cloudwatch_logs_delivery ? 1 : 0
  name              = "/aws/cloudtrail/${var.trail_name}"
  retention_in_days = var.cloudwatch_log_group_retention_days
  kms_key_id        = var.cloudwatch_logs_kms_key_arn
}

data "aws_iam_policy_document" "cloudtrail_to_cwlogs_assume" {
  count = var.enable_cloudwatch_logs_delivery ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudtrail_to_cwlogs" {
  count              = var.enable_cloudwatch_logs_delivery ? 1 : 0
  name               = "cloudtrail-to-cwlogs-${var.trail_name}"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_to_cwlogs_assume[0].json
}

data "aws_iam_policy_document" "cloudtrail_to_cwlogs" {
  count = var.enable_cloudwatch_logs_delivery ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "cloudtrail_to_cwlogs" {
  count  = var.enable_cloudwatch_logs_delivery ? 1 : 0
  name   = "cloudtrail-to-cwlogs"
  role   = aws_iam_role.cloudtrail_to_cwlogs[0].id
  policy = data.aws_iam_policy_document.cloudtrail_to_cwlogs[0].json
}

########################################
# CloudTrail trail
########################################

resource "aws_cloudtrail" "this" {
  name           = var.trail_name
  s3_bucket_name = aws_s3_bucket.cloudtrail.bucket
  s3_key_prefix  = local.prefix_path == "" ? null : local.prefix_path
  enable_logging = true

  is_multi_region_trail         = var.is_multi_region_trail
  include_global_service_events = var.include_global_service_events
  enable_log_file_validation    = var.enable_log_file_validation

  kms_key_id = aws_kms_key.cloudtrail.arn

  dynamic "insight_selector" {
    for_each = var.enable_cloudtrail_insights ? toset(["ApiCallRateInsight", "ApiErrorRateInsight"]) : toset([])
    content {
      insight_type = insight_selector.value
    }
  }

  # CloudWatch Logs delivery (optional)
  cloud_watch_logs_group_arn = var.enable_cloudwatch_logs_delivery ? aws_cloudwatch_log_group.cloudtrail[0].arn : null
  cloud_watch_logs_role_arn  = var.enable_cloudwatch_logs_delivery ? aws_iam_role.cloudtrail_to_cwlogs[0].arn : null

  # Management events always on; optional S3 data events.
  event_selector {
    include_management_events = true
    read_write_type           = "All"

    dynamic "data_resource" {
      for_each = var.enable_s3_data_events ? [1] : []
      content {
        type   = "AWS::S3::Object"
        values = var.s3_data_event_arn_prefixes
      }
    }
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail
  ]
}
