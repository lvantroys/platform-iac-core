aws_region = "us-east-1"

# Terraform state backend identifiers
state_bucket_name   = "fintech1-demo1-tfstate-us-east-1"
bootstrap_state_key = "platform-iac-core/global/00-bootstrap-state/terraform.tfstate"


owner       = "platform-team"
environment = "global"

app                 = "platform-core"
data_classification = "restricted"


kms_alias = "alias/platform/terraform-state"

enable_object_lock = false

# Only set these when enable_object_lock = true
# object_lock_mode = "GOVERNANCE"
# object_lock_days = 7

noncurrent_version_transition_days = 30
noncurrent_version_expiration_days = 3650

extra_tags = {
  "cost-center" = "finops-001"
  "compliance"  = "regulated-finance"
}
