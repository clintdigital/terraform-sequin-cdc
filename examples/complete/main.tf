# Complete example: database + multiple consumers (Kafka, SQS, Webhook) + backfill

module "sequin" {
  source = "../.."

  database_name = "production-db"
  postgres_host = var.postgres_host
  postgres_port = 5432
  postgres_db   = var.postgres_db
  postgres_user = var.postgres_user
  postgres_pass = var.postgres_pass
  postgres_ssl  = true

  replication_slots = [{
    publication_name = "sequin_pub"
    slot_name        = "sequin_slot"
  }]

  consumers = {
    orders-to-kafka = {
      tables = {
        include = [
          { name = "public.orders", group_column_names = ["customer_id"] },
          { name = "public.order_items" }
        ]
      }
      actions = ["insert", "update", "delete"]

      destination = {
        type           = "kafka"
        hosts          = var.kafka_hosts
        topic          = "database.orders"
        tls            = true
        username       = var.kafka_username
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }

      batch_size       = 10
      message_grouping = true
    }

    events-to-sqs = {
      tables = {
        include = [{ name = "public.events" }]
      }

      destination = {
        type              = "sqs"
        queue_url         = "https://sqs.us-east-1.amazonaws.com/123456789/events.fifo"
        region            = "us-east-1"
        access_key_id     = var.aws_access_key_id
        secret_access_key = var.aws_secret_access_key
        is_fifo           = true
      }
    }

    notifications-to-webhook = {
      tables = {
        include = [{ name = "public.notifications" }]
      }

      destination = {
        type               = "webhook"
        http_endpoint      = "https://api.example.com"
        http_endpoint_path = "/webhooks/sequin"
        batch              = true
      }
    }
  }

  backfills = {
    orders-backfill = {
      consumer_name = "orders-to-kafka"
      tables        = ["public.orders", "public.order_items"]
      state         = "active"
    }
  }
}
