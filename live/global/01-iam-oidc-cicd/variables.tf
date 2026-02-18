variable "aws_region" {
  type        = string
  description = "AWS region."
}

variable "assume_role_arn" {
  type        = string
  default     = null
  description = "Optional role ARN to assume for execution (break-glass runs)."
}

variable "owner" {
  type        = string
  description = "Tag: owner"
}

variable "environment" {
  type        = string
  default     = "global"
  description = "Tag: environment (global for this stack)."
}

variable "app" {
  type        = string
  default     = "platform-core"
  description = "Tag: app"
}

variable "data_classification" {
  type        = string
  default     = "restricted"
  description = "Tag: data-classification"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "extra_tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags to apply."
}

# --- Remote state backend references (from 00-bootstrap-state outputs) ---

variable "tfstate_bucket_arn" {
  type        = string
  description = "ARN of the S3 state bucket (from 00-bootstrap-state output)."
}

variable "tfstate_kms_key_arn" {
  type        = string
  description = "ARN of the KMS key encrypting Terraform state objects (from 00-bootstrap-state output)."
}

# --- GitHub OIDC settings ---

variable "github_org" {
  type        = string
  description = "GitHub org/owner, e.g. 'my-org'."
}

variable "github_issuer_url" {
  type        = string
  default     = "https://token.actions.githubusercontent.com"
  description = "OIDC issuer URL for GitHub Actions."
}

# For strong restriction, we require job_workflow_ref patterns.
# Example: "my-org/platform-iac-core/.github/workflows/plan.yml@refs/heads/main"
variable "allowed_workflow_refs_plan" {
  type        = list(string)
  description = "Allowed GitHub workflow refs for plan roles (job_workflow_ref claim)."
}

variable "allowed_workflow_refs_apply" {
  type        = list(string)
  description = "Allowed GitHub workflow refs for apply roles (job_workflow_ref claim)."
}

# --- Repository role definitions ---

# One object per repo. Each creates plan/apply roles per environment listed.
# state_prefixes should match how you write backend keys, e.g. "platform-iac-core/", "platform-iac-env/", "app-foo-iac/"
variable "repositories" {
  description = "Repo definitions that get CI roles. type must be one of: platform_core, platform_env, app"
  type = list(object({
    repo           = string
    type           = string
    environments   = list(string) # e.g. ["global"] or ["dev","stage","prod"]
    state_prefixes = list(string)
  }))

  validation {
    condition = alltrue([
      for r in var.repositories :
      contains(["platform_core", "platform_env", "app"], r.type)
    ])
    error_message = "repositories[*].type must be one of: platform_core, platform_env, app."
  }
}

# Optional: additional sub patterns for plan roles (GitHub 'sub' claim)
# Default allows heads/* and pull_request for same-repo workflows.
variable "plan_sub_patterns_extra" {
  type        = list(string)
  default     = []
  description = "Additional token.actions.githubusercontent.com:sub patterns for plan roles."
}

# Apply roles are restricted to:
# - main branch refs, OR
# - GitHub environment (recommended: dev/stage/prod environment approvals)
variable "apply_allow_main_branch" {
  type        = bool
  default     = true
  description = "Allow apply from refs/heads/main."
}
