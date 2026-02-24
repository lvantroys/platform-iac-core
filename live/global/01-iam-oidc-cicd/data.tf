data "aws_caller_identity" "current" {}

# Discover the current GitHub OIDC TLS cert thumbprint dynamically (avoid hardcoding)
data "tls_certificate" "github_oidc" {
  url = var.github_issuer_url
}

# -----------------------------
# Trust policies (assume role)
# -----------------------------

data "aws_iam_policy_document" "trust_plan" {
  for_each = local.repo_env_map

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:job_workflow_ref"
      values = [
        "lvantroys/platform-reusable-wf-infra/.github/workflows/terraform-plan.yml@refs/tags/v4",
        "lvantroys/platform-reusable-wf-infra/.github/workflows/terraform-plan.yml@refs/tags/v5"
      ]
    }

    # Restrict to repo + ref patterns
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.plan_sub_patterns[each.key]
    }
  }
}

data "aws_iam_policy_document" "trust_apply" {
  for_each = local.repo_env_map

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:job_workflow_ref"
      values = [
        "lvantroys/platform-reusable-wf-infra/.github/workflows/terraform-apply.yml@refs/tags/v4",
        "lvantroys/platform-reusable-wf-infra/.github/workflows/terraform-apply.yml@refs/tags/v5"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.apply_sub_patterns[each.key]
    }
  }
}

# -----------------------------
# Permission boundary (deny-only)
# Applied to CI roles to prevent tampering with state backend and itself.
# -----------------------------

data "aws_iam_policy_document" "permissions_boundary" {
  #  for_each = local.unique_repo_defs
  statement {
    sid    = "AllowTfstateListBucket"
    effect = "Allow"
    actions = ["s3:ListBucket",
      "s3:GetBucketPolicy",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketWebsite",
      "s3:GetBucketVersioning",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketLogging",
      "s3:GetLifecycleConfiguration",
      "s3:Get*"
    ]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid       = "AllowTfstateListBucketObjects"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/*"]
  }

  statement {
    sid    = "DenyStateBucketAdminChanges"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketObjectLockConfiguration"
    ]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid    = "AllowTfstateKmsUsage"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags"
    ]
    resources = [var.state_kms_key_arn]
  }

  statement {
    sid       = "AllowKmsListAliases"
    effect    = "Allow"
    actions   = ["kms:ListAliases"]
    resources = ["*"]
  }
  statement {
    sid    = "DenyStateKmsDestructiveOps"
    effect = "Deny"
    actions = [
      "kms:DisableKey",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:PutKeyPolicy",
      "kms:DeleteAlias",
      "kms:UpdateAlias"
    ]
    resources = [var.state_kms_key_arn]
  }

  statement {
    sid    = "DenyCreateLongLivedCreds"
    effect = "Deny"
    actions = [
      "iam:CreateAccessKey",
      "iam:UpdateAccessKey",
      "iam:DeleteAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:CreateUser",
      "iam:DeleteUser"
    ]
    resources = ["*"]
  }
}

# -----------------------------
# State access policies per repo
# scoped to that repo's state_prefixes
# -----------------------------

data "aws_iam_policy_document" "tfstate_access_by_repo" {
  for_each = local.unique_repo_defs

  statement {
    sid    = "StateBucketListScoped"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning"
    ]
    resources = [var.state_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [for p in each.value.state_prefixes : "${p}*"]
    }
  }

  statement {
    sid    = "StateObjectsRWScoped"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:AbortMultipartUpload"
    ]

    resources = flatten([
      for p in each.value.state_prefixes : [
        "${var.state_bucket_arn}/${p}*"
      ]
    ])
  }

  # KMS usage for SSE-KMS state objects (via S3)
  statement {
    sid    = "KmsForStateObjectsViaS3"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [var.state_kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }
  }
}

# -----------------------------
# Repo-type policies (PLAN)
# These are "read-only" enough for terraform refresh/data sources.
# -----------------------------

data "aws_iam_policy_document" "plan_platform_core" {
  statement {
    effect = "Allow"
    actions = [
      "iam:Get*", "iam:List*",
      "kms:Describe*", "kms:Get*", "kms:List*",
      "s3:Get*", "s3:List*",
      "cloudtrail:Describe*", "cloudtrail:Get*", "cloudtrail:List*", "cloudtrail:LookupEvents",
      "config:Describe*", "config:Get*", "config:List*",
      "securityhub:Describe*", "securityhub:Get*", "securityhub:List*",
      "guardduty:Get*", "guardduty:List*", "guardduty:Describe*",
      "access-analyzer:Get*", "access-analyzer:List*",
      "logs:Describe*", "logs:Get*", "logs:List*",
      "cloudwatch:Describe*", "cloudwatch:Get*", "cloudwatch:List*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "plan_platform_env" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "acm:Describe*", "acm:List*",
      "wafv2:Get*", "wafv2:List*",
      "route53:Get*", "route53:List*",
      "logs:Describe*", "logs:Get*", "logs:List*",
      "cloudwatch:Describe*", "cloudwatch:Get*", "cloudwatch:List*",
      "s3:Get*", "s3:List*",
      "iam:Get*", "iam:List*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "plan_app" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "autoscaling:Describe*",
      "elasticloadbalancing:Describe*",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
      "secretsmanager:GetResourcePolicy",
      "ssm:Get*", "ssm:List*",
      "logs:Describe*", "logs:Get*", "logs:List*",
      "cloudwatch:Describe*", "cloudwatch:Get*", "cloudwatch:List*",
      "iam:Get*", "iam:List*"
    ]
    resources = ["*"]
  }
}

# -----------------------------
# Repo-type policies (APPLY)
# These are intentionally scoped by actions (no Action:"*").
# Some AWS APIs do not support resource-level scoping; those require Resource:"*".
# -----------------------------

data "aws_iam_policy_document" "apply_platform_core" {
  statement {
    effect = "Allow"
    actions = [
      # IAM (for CI roles, boundaries, and later platform stacks)
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole", "iam:GetRole", "iam:ListRoles",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:ListPolicies", "iam:GetPolicy", "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion",
      "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:GetOpenIDConnectProvider", "iam:ListOpenIDConnectProviders",
      "iam:TagRole", "iam:UntagRole", "iam:TagPolicy", "iam:UntagPolicy",
      "iam:PassRole",

      # KMS
      "kms:CreateKey", "kms:DescribeKey", "kms:EnableKeyRotation", "kms:DisableKeyRotation",
      "kms:CreateAlias", "kms:DeleteAlias", "kms:UpdateAlias",
      "kms:PutKeyPolicy", "kms:GetKeyPolicy", "kms:ListKeys", "kms:ListAliases",
      "kms:TagResource", "kms:UntagResource",

      # S3 (audit/config buckets)
      "s3:CreateBucket", "s3:DeleteBucket",
      "s3:PutBucketPolicy", "s3:DeleteBucketPolicy", "s3:GetBucketPolicy",
      "s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketVersioning", "s3:GetBucketVersioning",
      "s3:PutEncryptionConfiguration", "s3:GetEncryptionConfiguration",
      "s3:PutBucketOwnershipControls", "s3:GetBucketOwnershipControls",
      "s3:PutLifecycleConfiguration", "s3:GetLifecycleConfiguration",
      "s3:ListBucket", "s3:GetBucketLocation",
      "s3:PutObject", "s3:GetObject", "s3:DeleteObject",

      # CloudTrail / Config / Security services
      "cloudtrail:CreateTrail", "cloudtrail:UpdateTrail", "cloudtrail:DeleteTrail",
      "cloudtrail:StartLogging", "cloudtrail:StopLogging",
      "cloudtrail:PutEventSelectors", "cloudtrail:GetEventSelectors",
      "cloudtrail:PutInsightSelectors", "cloudtrail:GetInsightSelectors",
      "config:PutConfigurationRecorder", "config:DeleteConfigurationRecorder",
      "config:PutDeliveryChannel", "config:DeleteDeliveryChannel",
      "config:StartConfigurationRecorder", "config:StopConfigurationRecorder",
      "config:PutConfigRule", "config:DeleteConfigRule",
      "securityhub:EnableSecurityHub", "securityhub:DisableSecurityHub",
      "guardduty:CreateDetector", "guardduty:DeleteDetector",
      "access-analyzer:CreateAnalyzer", "access-analyzer:DeleteAnalyzer",

      # Logs/CloudWatch
      "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:AssociateKmsKey", "logs:DisassociateKmsKey",
      "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "apply_platform_env" {
  statement {
    effect = "Allow"
    actions = [
      # VPC / networking
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateVpcEndpoint", "ec2:DeleteVpcEndpoints", "ec2:ModifyVpcEndpoint",
      "ec2:CreateFlowLogs", "ec2:DeleteFlowLogs",
      "ec2:CreateTags", "ec2:DeleteTags",

      # ALB
      "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule", "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags",

      # ACM
      "acm:RequestCertificate", "acm:DeleteCertificate", "acm:DescribeCertificate", "acm:ListCertificates",
      "acm:AddTagsToCertificate", "acm:RemoveTagsFromCertificate",

      # WAFv2
      "wafv2:CreateWebACL", "wafv2:UpdateWebACL", "wafv2:DeleteWebACL",
      "wafv2:AssociateWebACL", "wafv2:DisassociateWebACL",
      "wafv2:PutLoggingConfiguration", "wafv2:DeleteLoggingConfiguration",
      "wafv2:Get*", "wafv2:List*",

      # Route53
      "route53:ChangeResourceRecordSets", "route53:ListHostedZones", "route53:GetHostedZone",
      "route53:ListResourceRecordSets",

      # S3 for ALB logs bucket (note: ALB access logs use SSE-S3)
      "s3:CreateBucket", "s3:DeleteBucket",
      "s3:PutBucketPolicy", "s3:DeleteBucketPolicy", "s3:GetBucketPolicy",
      "s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketVersioning", "s3:GetBucketVersioning",
      "s3:PutEncryptionConfiguration", "s3:GetEncryptionConfiguration",
      "s3:PutLifecycleConfiguration", "s3:GetLifecycleConfiguration",
      "s3:PutBucketOwnershipControls", "s3:GetBucketOwnershipControls",
      "s3:ListBucket", "s3:GetBucketLocation",

      # Logs / CloudWatch
      "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:AssociateKmsKey", "logs:DisassociateKmsKey",
      "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards",

      # IAM read (for SG references, endpoint policies, etc.)
      "iam:Get*", "iam:List*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "apply_app" {
  statement {
    effect = "Allow"
    actions = [
      # EC2 / launch templates / SG
      "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate", "ec2:CreateLaunchTemplateVersion", "ec2:DeleteLaunchTemplateVersions",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags", "ec2:DeleteTags",

      # ASG
      "autoscaling:CreateAutoScalingGroup", "autoscaling:UpdateAutoScalingGroup", "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:PutScalingPolicy", "autoscaling:DeletePolicy",
      "autoscaling:StartInstanceRefresh", "autoscaling:CancelInstanceRefresh",
      "autoscaling:CreateOrUpdateTags", "autoscaling:DeleteTags",

      # Target groups (ALB target group is owned by app, listener rules by platform)
      "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags",

      # Secrets (metadata + versions)
      "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret", "secretsmanager:UpdateSecret",
      "secretsmanager:PutResourcePolicy", "secretsmanager:GetResourcePolicy",
      "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:DescribeSecret", "secretsmanager:TagResource", "secretsmanager:UntagResource",

      # IAM for instance profile/role
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:PassRole",
      "iam:TagRole", "iam:UntagRole",

      # SSM parameter contracts
      "ssm:PutParameter", "ssm:DeleteParameter", "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath",

      # Logs/CloudWatch
      "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:AssociateKmsKey", "logs:DisassociateKmsKey",
      "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards"
    ]
    resources = ["*"]
  }
}
