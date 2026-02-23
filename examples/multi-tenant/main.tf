# Multi-tenant example: one Sequin pipeline per tenant using for_each.
# Each tenant gets an isolated database connection and its own Kafka topic.
#
# Example tfvars:
#
# tenants = {
#   acme = {
#     postgres_host = "acme.db.example.com"
#     postgres_db   = "acme_prod"
#     postgres_user = "sequin"
#     postgres_pass = "secret-acme"
#   }
#   globex = {
#     postgres_host = "globex.db.example.com"
#     postgres_db   = "globex_prod"
#     postgres_user = "sequin"
#     postgres_pass = "secret-globex"
#   }
# }

module "sequin" {
  source   = "../.."
  for_each = var.tenants

  database_name = "${each.key}-db"
  postgres_host = each.value.postgres_host
  postgres_db   = each.value.postgres_db
  postgres_user = each.value.postgres_user
  postgres_pass = each.value.postgres_pass

  replication_slots = [{
    publication_name = "${each.key}_pub"
    slot_name        = "${each.key}_slot"
  }]

  consumers = {
    "${each.key}-changes" = {
      # Stream every change from every table into a tenant-scoped Kafka topic
      destination = {
        type           = "kafka"
        hosts          = var.kafka_hosts
        topic          = "cdc.${each.key}"
        tls            = true
        username       = var.kafka_username
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }

      message_grouping = true
    }
  }
}
