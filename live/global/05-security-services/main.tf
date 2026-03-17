########################################
# GuardDuty
########################################

resource "aws_guardduty_detector" "this" {
  count                        = var.enable_guardduty ? 1 : 0
  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_publishing_frequency

  dynamic "datasources" {
    for_each = (var.enable_guardduty && var.configure_guardduty_datasources) ? [1] : []
    content {
      dynamic "s3_logs" {
        for_each = var.guardduty_enable_s3_protection ? [1] : []
        content {
          enable = true
        }
      }

      dynamic "kubernetes" {
        for_each = var.guardduty_enable_kubernetes_audit_logs ? [1] : []
        content {
          audit_logs {
            enable = true
          }
        }
      }

      dynamic "malware_protection" {
        for_each = var.guardduty_enable_malware_protection_ebs ? [1] : []
        content {
          scan_ec2_instance_with_findings {
            ebs_volumes {
              enable = true
            }
          }
        }
      }
    }
  }
}

########################################
# IAM Access Analyzer
########################################

resource "aws_iam_service_linked_role" "accessanalyzer" {
  count            = (var.enable_access_analyzer && var.create_accessanalyzer_service_linked_role) ? 1 : 0
  aws_service_name = "access-analyzer.amazonaws.com"
  description      = "Service-linked role for IAM Access Analyzer"
}

resource "aws_accessanalyzer_analyzer" "this" {
  count         = var.enable_access_analyzer ? 1 : 0
  analyzer_name = var.access_analyzer_name
  type          = var.access_analyzer_type

  depends_on = [
    aws_iam_service_linked_role.accessanalyzer
  ]
}

########################################
# Security Hub CSPM
########################################

resource "aws_securityhub_account" "this" {
  count                     = var.enable_securityhub ? 1 : 0
  enable_default_standards  = var.securityhub_enable_default_standards
  control_finding_generator = var.securityhub_control_finding_generator
  auto_enable_controls      = var.securityhub_auto_enable_controls
}

# Security Hub enablement can be eventually consistent; wait a short time
resource "time_sleep" "wait_securityhub" {
  count           = var.enable_securityhub ? 1 : 0
  create_duration = "10s"
  depends_on      = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "standards" {
  for_each      = var.enable_securityhub ? local.securityhub_standards_arns : toset([])
  standards_arn = each.value

  depends_on = [time_sleep.wait_securityhub]
}
