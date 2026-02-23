output "database_id" {
  description = "The ID of the Sequin database connection resource."
  value       = sequin_database.this.id
}

output "consumer_ids" {
  description = "Map of consumer name to Sequin sink consumer ID for every consumer created by this module."
  value       = { for k, v in sequin_sink_consumer.this : k => v.id }
}

output "backfill_ids" {
  description = "Map of backfill name to Sequin backfill ID for every backfill created by this module."
  value       = { for k, v in sequin_backfill.this : k => v.id }
}
