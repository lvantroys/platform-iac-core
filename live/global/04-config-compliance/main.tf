########################################
# S3 bucket for AWS Config delivery
########################################

resource "aws_s3_bucket" "config" {
  bucket        = var.config_bucket_name
  force_destroy = var.bucket_force_destroy

  object_lock_enabled = var.enable_object_lock

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

########################################
# KMS CMK for AWS Config bucket SSE-KMS
########################################

data "aws_iam_policy_document" "config_kms" {
  # Root break-glass
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

  # Admin principals
  dynamic "statement" {
    for_each = length(compact(var.kms_admin_principal_arns)) > 0 ? [1] : []
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

  # Allow AWS Config service to use the key for S3 SSE-KMS
  # Keep this broad enough to avoid service delivery failures but still constrained to this account/region.
  statement {
    sid    = "AllowConfigServiceUseKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:config:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }

  # Optional: allow specified principals to decrypt delivered objects (investigations)
  dynamic "statement" {
    for_each = length(compact(var.kms_decrypt_principal_arns)) > 0 ? [1] : []
    content {
      sid    = "AllowInvestigatorsDecryptConfigObjects"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = compact(var.kms_decrypt_principal_arns)
      }
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = ["*"]
    }
  }
}

resource "aws_kms_key" "config" {
  description             = "CMK for AWS Config delivery bucket SSE-KMS"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.config_kms.json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "config" {
  name          = "alias/platform/config"
  target_key_id = aws_kms_key.config.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.config.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    id     = "abort-incomplete-mpu"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "config" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.config.id

  rule {
    default_retention {
      mode = var.object_lock_mode
      days = var.object_lock_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.config]
}

########################################
# Bucket policy: allow AWS Config to write
########################################

data "aws_iam_policy_document" "config_bucket_policy" {
  # Allow AWS Config to check permissions
  statement {
    sid     = "AWSConfigAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl", "s3:GetBucketLocation"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    resources = [aws_s3_bucket.config.arn]
  }

  # Allow AWS Config to write objects
  statement {
    sid     = "AWSConfigWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.config.arn}/${local.config_object_prefix}"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  # Deny insecure transport
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.config.arn,
      "${aws_s3_bucket.config.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id
  policy = data.aws_iam_policy_document.config_bucket_policy.json
}

########################################
# AWS Config: service-linked role
########################################

resource "aws_iam_service_linked_role" "config" {
  aws_service_name = "config.amazonaws.com"
  description      = "Service-linked role for AWS Config"
}

########################################
# AWS Config: recorder + channel + retention
########################################

resource "aws_config_configuration_recorder" "this" {
  name     = var.recorder_name
  role_arn = local.config_service_linked_role_arn

  recording_group {
    all_supported                 = var.record_all_supported
    include_global_resource_types = var.include_global_resource_types
  }

  depends_on = [aws_iam_service_linked_role.config]
}

resource "aws_config_delivery_channel" "this" {
  name           = var.delivery_channel_name
  s3_bucket_name = aws_s3_bucket.config.bucket
  s3_key_prefix  = local.prefix_path == "" ? null : local.prefix_path

  snapshot_delivery_properties {
    delivery_frequency = var.snapshot_delivery_frequency
  }

  depends_on = [
    aws_config_configuration_recorder.this,
    aws_s3_bucket_policy.config,
    aws_s3_bucket_server_side_encryption_configuration.config
  ]
}

resource "aws_config_retention_configuration" "this" {
  retention_period_in_days = var.config_retention_days
}

# Start recorder only after delivery channel exists
resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

########################################
# Optional: AWS Managed Config rules baseline
########################################

resource "aws_config_config_rule" "managed" {
  for_each = local.effective_managed_rules

  name        = replace(each.key, "_", "-")
  description = try(each.value.description, null)

  source {
    owner             = "AWS"
    source_identifier = each.value.source_identifier
  }

  input_parameters = try(each.value.input_parameters, null) == null ? null : jsonencode(each.value.input_parameters)

  maximum_execution_frequency = try(each.value.maximum_execution_frequency, null)

  depends_on = [aws_config_configuration_recorder_status.this]
}
