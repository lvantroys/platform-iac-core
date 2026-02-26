check "kms_admins_or_root" {
  assert {
    condition     = length(var.kms_admin_principal_arns) > 0
    error_message = "KMS keys always include account root in policy for break-glass; provide kms_admin_principal_arns for normal administration."
  }
}

check "usage_principals_provided_for_cicd" {
  assert {
    condition     = length(var.kms_usage_principal_arns) > 0
    error_message = "Provide kms_usage_principal_arns (CI roles + runtime roles) so workloads can encrypt/decrypt."
  }
}
