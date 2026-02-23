# Basic example: minimal setup — one database, one kafka consumer.
# Best starting point if you're new to the module.

module "sequin" {
  source = "../.."

  database_name = "my-db"
  postgres_host = var.postgres_host
  postgres_db   = var.postgres_db
  postgres_user = var.postgres_user
  postgres_pass = var.postgres_pass

  consumers = {
    all-changes-to-kafka = {
      # No tables/schemas filter — receives every change from every table
      destination = {
        type           = "kafka"
        hosts          = var.kafka_hosts
        topic          = "cdc.all"
        tls            = true
        username       = var.kafka_username
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }
    }
  }
}
