locals {
  # Convert standard paths to full standards ARNs.
  securityhub_standards_arns = toset([
    for s in var.securityhub_standards :
    format("arn:%s:securityhub:%s::standards/%s", data.aws_partition.current.partition, var.aws_region, s)
  ])
}
