# 01-iam-oidc-cicd

Creates GitHub Actions OIDC provider and CI roles (plan/apply) for:
- platform-iac-core
- platform-iac-env
- app-<name>-iac

This stack is intended to run AFTER 00-bootstrap-state (state bucket + KMS exist).

## How it works

- Adds IAM OIDC provider for https://token.actions.githubusercontent.com
- Creates roles with trust policy restricted by:
  - repository (org/repo)
  - workflow ref (job_workflow_ref)
  - for apply roles: environment claim OR main branch ref
- Attaches:
  - permissions boundary (deny-only guardrails)
  - state access policy scoped to each repo state prefix
  - repo-type policies for plan/apply

## Run instructions

1) Create backend.hcl (do not commit)
   - copy backend.hcl.example -> backend.hcl
   - fill bucket, region, kms_key_id, key

2) Init/plan/apply
   terraform -chdir=live/global/01-iam-oidc-cicd init -reconfigure -backend-config=backend.hcl
   terraform -chdir=live/global/01-iam-oidc-cicd plan
   terraform -chdir=live/global/01-iam-oidc-cicd apply

## GitHub workflow requirements

Your GitHub Actions workflow must include:
- permissions: id-token: write
- permissions: contents: read

And for apply to stage/prod, use GitHub Environments and approval gates.
