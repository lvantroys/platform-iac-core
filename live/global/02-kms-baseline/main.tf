########################################
# KMS Key Policies (per key)
########################################

# LOGS key policy (CloudWatch Logs, VPC Flow Logs to CWL, etc.)
data "aws_iam_policy_document" "kms_logs_policy" {
  # Root full control (break-glass)
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

  # Key administrators (no encrypt/decrypt needed)
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
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
        "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
        "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
      ]
      resources = ["*"]
    }
  }

  # Usage principals (Encrypt/Decrypt/DataKey)
  dynamic "statement" {
    for_each = length(var.kms_usage_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowKeyUsage"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms_usage_principal_arns
      }
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"
      ]
      resources = ["*"]

      dynamic "condition" {
        for_each = var.enable_viaservice_conditions ? [1] : []
        content {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["logs.${var.aws_region}.amazonaws.com"]
        }
      }
    }
  }

  # Allow grants for AWS resources (helps services attach)
  dynamic "statement" {
    for_each = length(var.kms_usage_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowGrantManagementForAWSResources"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms_usage_principal_arns
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

# SECRETS key policy (Secrets Manager)
data "aws_iam_policy_document" "kms_secrets_policy" {
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
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
        "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
        "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.kms_usage_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowKeyUsage"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms_usage_principal_arns
      }
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"
      ]
      resources = ["*"]

      dynamic "condition" {
        for_each = var.enable_viaservice_conditions ? [1] : []
        content {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
        }
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.kms_usage_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowGrantManagementForAWSResources"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms_usage_principal_arns
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

# SSM key policy (Parameter Store SecureString)
data "aws_iam_policy_document" "kms_ssm_policy" {
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
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
        "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
        "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.kms_usage_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowKeyUsage"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms_usage_principal_arns
      }
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"
      ]
      resources = ["*"]

      dynamic "condition" {
        for_each = var.enable_viaservice_conditions ? [1] : []
        content {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["ssm.${var.aws_region}.amazonaws.com"]
        }
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.kms_usage_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowGrantManagementForAWSResources"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms_usage_principal_arns
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

# EBS key policy (default EBS encryption)
data "aws_iam_policy_document" "kms_ebs_policy" {
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
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
        "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
        "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
      ]
      resources = ["*"]
    }
  }

  # For EBS, ViaService must be ec2.<region>.amazonaws.com
  dynamic "statement" {
    for_each = length(var.kms_usage_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowKeyUsage"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms_usage_principal_arns
      }
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"
      ]
      resources = ["*"]

      dynamic "condition" {
        for_each = var.enable_viaservice_conditions ? [1] : []
        content {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["ec2.${var.aws_region}.amazonaws.com"]
        }
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.kms_usage_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowGrantManagementForAWSResources"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms_usage_principal_arns
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

########################################
# Keys + Aliases
########################################

resource "aws_kms_key" "logs" {
  description             = "Platform KMS key for CloudWatch Logs and log-like services"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_logs_policy.json
  tags                    = local.common_tags

  lifecycle { prevent_destroy = true }
}

resource "aws_kms_alias" "logs" {
  name          = local.aliases.logs
  target_key_id = aws_kms_key.logs.key_id
}

resource "aws_kms_key" "secrets" {
  description             = "Platform KMS key for Secrets Manager"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_secrets_policy.json
  tags                    = local.common_tags

  lifecycle { prevent_destroy = true }
}

resource "aws_kms_alias" "secrets" {
  name          = local.aliases.secrets
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_kms_key" "ssm" {
  description             = "Platform KMS key for SSM Parameter Store SecureString"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_ssm_policy.json
  tags                    = local.common_tags

  lifecycle { prevent_destroy = true }
}

resource "aws_kms_alias" "ssm" {
  name          = local.aliases.ssm
  target_key_id = aws_kms_key.ssm.key_id
}

resource "aws_kms_key" "ebs" {
  description             = "Platform KMS key for default EBS encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_ebs_policy.json
  tags                    = local.common_tags

  lifecycle { prevent_destroy = true }
}

resource "aws_kms_alias" "ebs" {
  name          = local.aliases.ebs
  target_key_id = aws_kms_key.ebs.key_id
}

########################################
# EBS encryption-by-default (optional)
########################################

resource "aws_ebs_encryption_by_default" "this" {
  count   = var.enable_ebs_encryption_by_default ? 1 : 0
  enabled = true
}

resource "aws_ebs_default_kms_key" "this" {
  count   = var.enable_ebs_encryption_by_default ? 1 : 0
  key_arn = aws_kms_key.ebs.arn
}
