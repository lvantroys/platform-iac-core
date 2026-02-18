data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "AllowRootAccountFullAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.account_root_arn]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.kms_admin_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowKeyAdministrators"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = var.kms_admin_principal_arns
      }

      actions = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(local.kms_user_principals) > 0 ? [1] : []
    content {
      sid    = "AllowKeyUsageForStatePrincipals"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = local.kms_user_principals
      }

      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(local.kms_user_principals) > 0 ? [1] : []
    content {
      sid    = "AllowGrantManagementForAWSResources"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = local.kms_user_principals
      }

      actions   = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
      resources = ["*"]

      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }
    }
  }
}

data "aws_iam_policy_document" "state_bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  statement {
    sid    = "DenyWrongKmsKeyForObjectUploads"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.tfstate.arn]
    }
  }

  statement {
    sid    = "AllowStateWritersBucketLevel"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.state_writer_principals
    }

    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning"
    ]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid    = "AllowStateWritersObjectLevel"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.state_writer_principals
    }

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:AbortMultipartUpload"
    ]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }

  dynamic "statement" {
    for_each = length(local.state_reader_principals) > 0 ? [1] : []
    content {
      sid    = "AllowStateReadersBucketLevel"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = local.state_reader_principals
      }

      actions = [
        "s3:ListBucket",
        "s3:ListBucketVersions",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning"
      ]
      resources = [aws_s3_bucket.tfstate.arn]
    }
  }

  dynamic "statement" {
    for_each = length(local.state_reader_principals) > 0 ? [1] : []
    content {
      sid    = "AllowStateReadersObjectLevel"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = local.state_reader_principals
      }

      actions = [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ]
      resources = ["${aws_s3_bucket.tfstate.arn}/*"]
    }
  }
}
