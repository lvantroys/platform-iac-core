# 00-bootstrap-state

Bootstraps Terraform remote state infrastructure for `platform-iac-core`:
- S3 state bucket (versioned, private, KMS-encrypted)
- KMS key for state encryption
- Bucket policy enforcing TLS + correct SSE-KMS key
- Explicit writer/reader principal access controls

## Why this folder exists

Terraform remote backend needs infrastructure that does not exist yet.
So this stack is applied once with local state, then migrated to S3 backend.

## Usage

### 1) Prepare variables
```bash
cp global.auto.tfvars.example global.auto.tfvars
# Edit values
