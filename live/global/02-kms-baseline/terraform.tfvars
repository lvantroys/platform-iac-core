aws_region = "us-east-1"

owner               = "platform-team"
environment         = "global"
app                 = "platform-core"
data_classification = "restricted"

# Principals that can administer the keys (security/platform admins)
kms_admin_principal_arns = [
  "arn:aws:iam::219818470664:role/platform-security-admin"
]

# Principals that can use the keys (CI roles + runtime roles)
kms_usage_principal_arns = [
  "arn:aws:iam::219818470664:role/gha-platform-iac-core-global-apply",
  "arn:aws:iam::219818470664:role/gha-platform-iac-core-global-plan"
]

enable_viaservice_conditions     = true
enable_ebs_encryption_by_default = true

extra_tags = {
  compliance = "regulated-finance"
}
