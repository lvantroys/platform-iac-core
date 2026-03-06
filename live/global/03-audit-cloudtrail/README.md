# 03-audit-cloudtrail

Creates the account baseline CloudTrail trail + dedicated S3 bucket + dedicated KMS CMK for CloudTrail log encryption.

Security defaults:
- Multi-region trail + include global service events
- Log file validation enabled
- CloudTrail S3 bucket is private, versioned, Block Public Access enabled, BucketOwnerEnforced
- SSE-KMS enforced for CloudTrail log objects (bucket policy + default bucket encryption)
- KMS key policy follows AWS-required statements for CloudTrail

Optional features:
- CloudWatch Logs delivery (disabled by default)
- S3 data events (disabled by default; can be expensive)

## Apply order (recommended)
- 00-bootstrap-state
- 01-iam-oidc-cicd
- 02-kms-baseline
- 03-audit-cloudtrail

## Notes
- This stack creates its own CMK for CloudTrail encryption (separate from the baseline "logs" key).
- The trail ARN is constructed from `trail_name` and account/region to avoid create-time dependency cycles.
