check "s3_data_events_requires_prefixes" {
  assert {
    condition     = var.enable_s3_data_events == false || length(var.s3_data_event_arn_prefixes) > 0
    error_message = "enable_s3_data_events=true requires s3_data_event_arn_prefixes to be non-empty."
  }
}
