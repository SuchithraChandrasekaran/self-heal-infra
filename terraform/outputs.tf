output "toy_service_url" {
  description = "Public URL of the toy service API"
  value       = module.toy_service.api_url
}

output "chaos_toggle_url" {
  description = "POST here to flip the chaos flag between healthy and degraded"
  value       = module.toy_service.chaos_toggle_url
}
