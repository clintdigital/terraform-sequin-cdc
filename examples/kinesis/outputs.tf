output "database_id" {
  description = "ID of the Sequin database connection"
  value       = module.sequin.database_id
}

output "consumer_ids" {
  description = "Map of consumer name → ID"
  value       = module.sequin.consumer_ids
}

output "backfill_ids" {
  description = "Map of backfill name → ID"
  value       = module.sequin.backfill_ids
}
