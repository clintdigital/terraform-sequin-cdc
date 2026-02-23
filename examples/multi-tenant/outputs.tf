output "database_ids" {
  description = "Map of tenant name → Sequin database ID"
  value       = { for k, v in module.sequin : k => v.database_id }
}

output "consumer_ids" {
  description = "Map of tenant name → consumer IDs map"
  value       = { for k, v in module.sequin : k => v.consumer_ids }
}
