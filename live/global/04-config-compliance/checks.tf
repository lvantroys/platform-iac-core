check "object_lock_requires_retention" {
  assert {
    condition     = var.enable_object_lock == false || var.object_lock_days > 0
    error_message = "enable_object_lock=true requires object_lock_days > 0."
  }
}

check "managed_rules_nonempty_when_enabled" {
  assert {
    condition     = var.enable_managed_rules == false || length(local.effective_managed_rules) > 0
    error_message = "enable_managed_rules=true requires at least one managed rule (either managed_rules input or defaults)."
  }
}
