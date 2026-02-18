check "repos_defined" {
  assert {
    condition     = length(var.repositories) >= 1
    error_message = "repositories must include at least one repo definition."
  }
}

check "workflow_refs_defined" {
  assert {
    condition     = length(var.allowed_workflow_refs_plan) >= 1 && length(var.allowed_workflow_refs_apply) >= 1
    error_message = "allowed_workflow_refs_plan/apply must be set (restrict job_workflow_ref)."
  }
}

check "state_prefixes_nonempty" {
  assert {
    condition = alltrue([
      for r in var.repositories : length(r.state_prefixes) >= 1
    ])
    error_message = "Each repository must define at least one state_prefix."
  }
}
