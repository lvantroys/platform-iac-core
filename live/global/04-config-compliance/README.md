# 04-config-compliance

Enables AWS Config for this account/region and delivers:
- configuration snapshots + config history
- compliance evaluations (if managed rules enabled)

This stack creates:
- Dedicated S3 bucket for AWS Config delivery (private, versioned, SSE-KMS, BPA on)
- Dedicated KMS CMK + alias for AWS Config delivery encryption
- AWS Config configuration recorder + delivery channel + retention
- Optional AWS managed Config rules baseline

## Notes
- AWS Config is regional. Deploy this stack in each region you want Config enabled.
- AWS Config uses a service-linked role (AWSServiceRoleForConfig). This stack creates it.
  If it already exists in the account, import it:
    terraform import aws_iam_service_linked_role.config config.amazonaws.com

## Apply order (recommended)
- 00-bootstrap-state
- 01-iam-oidc-cicd
- 02-kms-baseline (optional)
- 03-audit-cloudtrail (optional but recommended)
- 04-config-compliance

## Common operations
- Create backend.hcl from backend.hcl.example (do not commit backend.hcl)
- terraform init -reconfigure -backend-config=backend.hcl
- terraform plan / apply
