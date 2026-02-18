provider "aws" {
  region = var.aws_region

  dynamic "assume_role" {
    for_each = var.assume_role_arn == null ? [] : [1]
    content {
      role_arn = var.assume_role_arn
    }
  }

  default_tags {
    tags = merge(
      {
        "env"                 = var.environment
        "app"                 = var.app
        "owner"               = var.owner
        "data-classification" = var.data_classification
        "layer"               = "iam-oidc-cicd"
        "managed-by"          = "terraform"
        "repo"                = "platform-iac-core"
      },
      var.extra_tags
    )
  }
}
