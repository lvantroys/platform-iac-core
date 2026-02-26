data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Helper: root principal for break-glass
locals {
  account_root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
}

# Base key policy shared pattern: root + optional admins + usage principals
# We will generate one policy per key so we can apply service-scoping per key type.
