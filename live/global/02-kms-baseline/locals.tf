locals {
  common_tags = merge(
    {
      env                 = var.environment
      app                 = var.app
      owner               = var.owner
      data-classification = var.data_classification
      layer               = "kms-baseline"
      managed-by          = "terraform"
      repo                = "platform-iac-core"
    },
    var.extra_tags
  )

  # Standard aliases
  aliases = {
    logs    = "alias/platform/logs"
    secrets = "alias/platform/secrets" # pragma: allowlist secret
    ssm     = "alias/platform/ssm"
    ebs     = "alias/platform/ebs"
  }
}
