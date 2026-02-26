# 02-kms-baseline

Creates baseline customer-managed KMS keys (CMKs) + aliases for platform-wide encryption defaults.

Keys created:
- alias/platform/logs          (CloudWatch Logs, VPC Flow Logs, etc.)
- alias/platform/secrets       (Secrets Manager)
- alias/platform/ssm           (SSM Parameter Store SecureString / Session Manager logs if used)
- alias/platform/ebs           (Default EBS encryption, if enabled)

This stack is intended to be applied by CI/CD (OIDC) after:
- 00-bootstrap-state
- 01-iam-oidc-cicd

## Usage

1) Create backend.hcl (do not commit)
   - copy backend.hcl.example -> backend.hcl
   - fill bucket, region, kms_key_id, key

2) Init/plan/apply
   terraform -chdir=live/global/02-kms-baseline init -reconfigure -backend-config=backend.hcl
   terraform -chdir=live/global/02-kms-baseline plan
   terraform -chdir=live/global/02-kms-baseline apply

## Notes / guardrails

- Key admin principals and key usage principals are separate.
- Key policies support "kms:ViaService" restrictions for common AWS services.
- EBS encryption-by-default is optional but recommended for regulated workloads.
