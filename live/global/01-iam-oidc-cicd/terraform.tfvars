aws_region = "us-east-1"

owner               = "platform-team"
environment         = "global"
app                 = "platform-core"
data_classification = "restricted"

# From 00-bootstrap-state outputs:
state_bucket_name = "fintech1-demo1-tfstate-us-east-1"
state_bucket_arn  = "arn:aws:s3:::fintech1-demo1-tfstate-us-east-1"
state_kms_key_arn = "arn:aws:kms:us-east-1:219818470664:key/3cb40a2f-1872-4ebf-acbb-45e8a6e5c28d"

github_org = "lvantroys"

# Strongly restrict which workflow files can assume roles
allowed_workflow_refs_plan = [
  "lvantroys/platform-reusable-wf-infra/.github/workflows/terraform-plan.yml@refs/tags/v3",
  "lvantroys/platform-reusable-wf-infra/.github/workflows/terraform-plan.yml@refs/tags/v4",
  "lvantroys/platform-reusable-wf-infra/.github/workflows/terraform-plan.yml@refs/tags/v5",
  "lvantroys/platform-iac-core/.github/workflows/plan.yml@refs/heads/main",
  "lvantroys/platform-iac-env/.github/workflows/plan.yml@refs/heads/main",
  "lvantroys/app-simple-flask-svc-iac/.github/workflows/plan.yml@refs/heads/main"
]

allowed_workflow_refs_apply = [
  "lvantroys/platform-reusable-wf-infra/.github/workflows/terraform-apply.yml@refs/tags/v3",
  "lvantroys/platform-reusable-wf-infra/.github/workflows/terraform-apply.yml@refs/tags/v4",
  "lvantroys/platform-reusable-wf-infra/.github/workflows/terraform-apply.yml@refs/tags/v5",
  "lvantroys/platform-iac-core/.github/workflows/apply.yml@refs/heads/main",
  "lvantroys/platform-iac-env/.github/workflows/apply.yml@refs/heads/main",
  "lvantroys/app-simple-flask-svc-iac/.github/workflows/apply.yml@refs/heads/main"
]

# Roles are created per repo × environment
repositories = [
  {
    repo           = "platform-iac-core"
    type           = "platform_core"
    environments   = ["global"]
    state_prefixes = ["platform-iac-core/"]
  },
  {
    repo           = "platform-iac-env"
    type           = "platform_env"
    environments   = ["dev", "stage", "prod"]
    state_prefixes = ["platform-iac-env/"]
  },
  {
    repo           = "app-simple-flask-svc-iac"
    type           = "app"
    environments   = ["dev", "stage", "prod"]
    state_prefixes = ["app-simple-flask-svc-iac/"]
  }
]

# Optional: also allow apply from main branch ref (in addition to GitHub environment gating)
apply_allow_main_branch = true

extra_tags = {
  "cost-center" = "finops-001"
  "compliance"  = "regulated-finance"
}
