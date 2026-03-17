# 05-security-services

Enables baseline AWS security services in this account/region using secure defaults.

This stack can enable:
- Amazon GuardDuty (threat detection)
- AWS Security Hub CSPM (security posture / standards)
- IAM Access Analyzer (unintended access/sharing analysis)

## Regional behavior
These services are regional. Deploy this stack in each region you want coverage in.

## Recommended ordering
- 00-bootstrap-state (tfstate backend)
- 01-iam-oidc-cicd (CI roles/boundaries)
- 03-audit-cloudtrail (CloudTrail)
- 04-config-compliance (AWS Config)
- 05-security-services (this stack)

Notes:
- Security Hub CSPM relies on AWS Config being enabled/recording to evaluate many controls.
- If a service-linked role already exists (e.g., Access Analyzer), Terraform may require import:
    terraform import aws_iam_service_linked_role.accessanalyzer access-analyzer.amazonaws.com

## Usage
1) Create backend.hcl from backend.hcl.example (do not commit backend.hcl)
2) terraform init -reconfigure -backend-config=backend.hcl
3) terraform plan / apply
