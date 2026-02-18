check "cicd_writer_is_defined" {
  assert {
    condition     = length(var.allowed_state_writer_principal_arns) > 0
    error_message = "At least one CI/CD writer principal ARN must be provided in allowed_state_writer_principal_arns."
  }
}

check "lifecycle_transition_before_expiration" {
  assert {
    condition     = var.noncurrent_version_expiration_days == 0 || var.noncurrent_version_expiration_days > var.noncurrent_version_transition_days
    error_message = "noncurrent_version_expiration_days must be 0 or greater than noncurrent_version_transition_days."
  }
}
