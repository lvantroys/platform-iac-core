output "github_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN of the GitHub OIDC provider."
}

output "permissions_boundary_arn" {
  value       = aws_iam_policy.permissions_boundary.arn
  description = "ARN of the deny-only permissions boundary applied to CI roles."
}

output "plan_role_arns" {
  description = "Plan role ARNs per repo+env."
  value = {
    for k, r in aws_iam_role.plan :
    k => r.arn
  }
}

output "apply_role_arns" {
  description = "Apply role ARNs per repo+env."
  value = {
    for k, r in aws_iam_role.apply :
    k => r.arn
  }
}
