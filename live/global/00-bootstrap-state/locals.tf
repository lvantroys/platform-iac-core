locals {
  account_root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"

  state_writer_principals = distinct(concat(
    [local.account_root_arn], # break-glass/root retained
    var.allowed_state_writer_principal_arns
  ))

  state_reader_principals = distinct(var.allowed_state_reader_principal_arns)

  kms_user_principals = distinct(concat(
    local.state_writer_principals,
    local.state_reader_principals
  ))

  common_tags = merge(
    {
      "env"                 = var.environment
      "app"                 = var.app
      "owner"               = var.owner
      "data-classification" = var.data_classification
      "layer"               = "bootstrap-state"
      "managed-by"          = "terraform"
      "repo"                = "platform-iac-core"
    },
    var.extra_tags
  )
}
