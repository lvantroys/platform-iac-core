locals {
  common_tags = merge(
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

  # Build repo × env matrix
  repo_env_matrix = flatten([
    for r in var.repositories : [
      for e in r.environments : {
        repo           = r.repo
        type           = r.type
        env            = e
        state_prefixes = r.state_prefixes
      }
    ]
  ])

  repo_env_map = {
    for x in local.repo_env_matrix :
    "${x.repo}__${x.env}" => x
  }

  # Role naming
  # Keep under IAM 64 char constraint (repo names should be reasonable)
  role_name_plan  = { for k, v in local.repo_env_map : k => "gha-${v.repo}-${v.env}-plan" }
  role_name_apply = { for k, v in local.repo_env_map : k => "gha-${v.repo}-${v.env}-apply" }

  # Plan sub patterns (repo-scoped)
  # Includes pull_request and heads/* patterns for same-repo workflows.
  plan_sub_patterns = {
    for k, v in local.repo_env_map : k => distinct(concat(
      [
        "repo:${var.github_org}/${v.repo}:ref:refs/heads/*",
        "repo:${var.github_org}/${v.repo}:ref:refs/tags/*",
        "repo:${var.github_org}/${v.repo}:pull_request"
      ],
      var.plan_sub_patterns_extra
    ))
  }

  # Apply sub patterns: main branch and/or environment claim
  apply_sub_patterns = {
    for k, v in local.repo_env_map : k => distinct(compact(concat(
      var.apply_allow_main_branch ? ["repo:${var.github_org}/${v.repo}:ref:refs/heads/main"] : [],
      ["repo:${var.github_org}/${v.repo}:environment:${v.env}"]
    )))
  }

  unique_repo_defs = {
    for r in var.repositories : r.repo => r
  }
}
