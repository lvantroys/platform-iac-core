resource "aws_iam_openid_connect_provider" "github" {
  url             = var.github_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
  tags            = local.common_tags
}

# Permission boundary (deny-only)
resource "aws_iam_policy" "permissions_boundary" {
  name        = "pb-terraform-cicd-guardrails"
  description = "Deny-only permissions boundary for Terraform CI roles (protects state backend and blocks long-lived creds)."
  policy      = data.aws_iam_policy_document.permissions_boundary.json
  tags        = local.common_tags
}

# TF state access policies per repo (scoped to state prefixes)
resource "aws_iam_policy" "tfstate_access_by_repo" {
  for_each    = local.unique_repo_defs
  name        = "tfstate-access-${each.key}"
  description = "Access to Terraform state bucket scoped to repo prefixes for ${each.key}."
  policy      = data.aws_iam_policy_document.tfstate_access_by_repo[each.key].json
  tags        = local.common_tags
}

# Repo-type policies (plan/apply)
resource "aws_iam_policy" "plan_platform_core" {
  name        = "tf-plan-platform-core"
  description = "Read permissions for terraform plan (platform core)."
  policy      = data.aws_iam_policy_document.plan_platform_core.json
  tags        = local.common_tags
}

resource "aws_iam_policy" "plan_platform_env" {
  name        = "tf-plan-platform-env"
  description = "Read permissions for terraform plan (platform env)."
  policy      = data.aws_iam_policy_document.plan_platform_env.json
  tags        = local.common_tags
}

resource "aws_iam_policy" "plan_app" {
  name        = "tf-plan-app"
  description = "Read permissions for terraform plan (app)."
  policy      = data.aws_iam_policy_document.plan_app.json
  tags        = local.common_tags
}

resource "aws_iam_policy" "apply_platform_core" {
  name        = "tf-apply-platform-core"
  description = "Apply permissions for platform-iac-core stacks."
  policy      = data.aws_iam_policy_document.apply_platform_core.json
  tags        = local.common_tags
}

resource "aws_iam_policy" "apply_platform_env" {
  name        = "tf-apply-platform-env"
  description = "Apply permissions for platform-iac-env stacks."
  policy      = data.aws_iam_policy_document.apply_platform_env.json
  tags        = local.common_tags
}

resource "aws_iam_policy" "apply_app" {
  name        = "tf-apply-app"
  description = "Apply permissions for app iac stacks."
  policy      = data.aws_iam_policy_document.apply_app.json
  tags        = local.common_tags
}

# -----------------------------
# Roles (plan/apply) per repo×env
# -----------------------------

resource "aws_iam_role" "plan" {
  for_each             = local.repo_env_map
  name                 = local.role_name_plan[each.key]
  assume_role_policy   = data.aws_iam_policy_document.trust_plan[each.key].json
  permissions_boundary = aws_iam_policy.permissions_boundary.arn
  tags                 = merge(local.common_tags, { "ci-role" = "plan", "target-repo" = each.value.repo, "target-env" = each.value.env })
}

resource "aws_iam_role" "apply" {
  for_each             = local.repo_env_map
  name                 = local.role_name_apply[each.key]
  assume_role_policy   = data.aws_iam_policy_document.trust_apply[each.key].json
  permissions_boundary = aws_iam_policy.permissions_boundary.arn
  tags                 = merge(local.common_tags, { "ci-role" = "apply", "target-repo" = each.value.repo, "target-env" = each.value.env })
}

# Attach state access policy by repo to both plan/apply roles
resource "aws_iam_role_policy_attachment" "plan_state" {
  for_each   = local.repo_env_map
  role       = aws_iam_role.plan[each.key].name
  policy_arn = aws_iam_policy.tfstate_access_by_repo[each.value.repo].arn
}

resource "aws_iam_role_policy_attachment" "apply_state" {
  for_each   = local.repo_env_map
  role       = aws_iam_role.apply[each.key].name
  policy_arn = aws_iam_policy.tfstate_access_by_repo[each.value.repo].arn
}

# Attach repo-type plan policies
resource "aws_iam_role_policy_attachment" "plan_type_policy" {
  for_each = local.repo_env_map

  role = aws_iam_role.plan[each.key].name

  policy_arn = (
    each.value.type == "platform_core" ? aws_iam_policy.plan_platform_core.arn :
    each.value.type == "platform_env" ? aws_iam_policy.plan_platform_env.arn :
    aws_iam_policy.plan_app.arn
  )
}

# Attach repo-type apply policies
resource "aws_iam_role_policy_attachment" "apply_type_policy" {
  for_each = local.repo_env_map

  role = aws_iam_role.apply[each.key].name

  policy_arn = (
    each.value.type == "platform_core" ? aws_iam_policy.apply_platform_core.arn :
    each.value.type == "platform_env" ? aws_iam_policy.apply_platform_env.arn :
    aws_iam_policy.apply_app.arn
  )
}
