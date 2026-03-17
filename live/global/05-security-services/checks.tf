check "securityhub_standards_required_when_defaults_disabled" {
  assert {
    condition = (
      var.enable_securityhub == false
      || var.securityhub_enable_default_standards == true
      || length(var.securityhub_standards) > 0
    )
    error_message = "If enable_securityhub=true and securityhub_enable_default_standards=false, provide at least one standards entry in securityhub_standards."
  }
}
