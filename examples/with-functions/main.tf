# Function references example: demonstrates all four function types
# (filter, enrichment, transform, routing)
#
# IMPORTANT: Functions must be created in the Sequin UI or API BEFORE
# referencing them here. This module does not manage function resources —
# it only references them by name.
#
# Function types:
# - filter_function: Drop/skip messages based on criteria (e.g., filter out test data)
# - enrichment_function: Add additional fields to messages (e.g., fetch user info)
# - transform_function: Modify message structure/content (e.g., flatten nested objects)
# - routing_function: Dynamically choose destination topic/queue (e.g., route by tenant)

module "sequin" {
  source = "../.."

  database_name = "functions-demo-db"
  postgres_host = var.postgres_host
  postgres_db   = var.postgres_db
  postgres_user = var.postgres_user
  postgres_pass = var.postgres_pass

  consumers = {
    # Example 1: Filter function
    # Only sends orders above $100 to Kafka
    high-value-orders = {
      tables = {
        include = [{ name = "public.orders" }]
      }

      # Reference a filter function that drops orders with amount < 100
      filter_function = "high-value-filter"

      destination = {
        type           = "kafka"
        hosts          = var.kafka_hosts
        topic          = "orders.high-value"
        tls            = true
        username       = var.kafka_username
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }
    }

    # Example 2: Enrichment function
    # Enriches user records with additional metadata
    enriched-users = {
      tables = {
        include = [{ name = "public.users" }]
      }

      # Reference an enrichment function that adds user segment, lifetime_value, etc.
      enrichment_function = "user-enrichment"

      destination = {
        type              = "sqs"
        queue_url         = var.sqs_queue_url
        region            = var.aws_region
        access_key_id     = var.aws_access_key_id
        secret_access_key = var.aws_secret_access_key
      }
    }

    # Example 3: Transform function
    # Reshapes event data before sending
    transformed-events = {
      tables = {
        include = [{ name = "public.events" }]
      }

      # Reference a transform function that flattens nested JSON, renames fields, etc.
      transform_function = "event-transformer"

      destination = {
        type               = "webhook"
        http_endpoint      = var.webhook_endpoint
        http_endpoint_path = "/events"
        batch              = true
      }
    }

    # Example 4: Routing function
    # Dynamically routes messages to different topics based on content
    tenant-routed-changes = {
      tables = {
        include = [
          { name = "public.tenants" },
          { name = "public.tenant_data" }
        ]
      }

      # Reference a routing function that sends each tenant to their own topic
      routing_function = "tenant-router"

      destination = {
        type           = "kafka"
        hosts          = var.kafka_hosts
        topic          = "tenants.default" # fallback topic
        tls            = true
        username       = var.kafka_username
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }
    }

    # Example 5: Combined functions
    # Uses filter + enrichment + transform + routing together
    orders-pipeline = {
      tables = {
        include = [{ name = "public.orders" }]
      }

      # Functions are applied in order: filter → enrichment → transform → routing
      filter_function     = "orders-filter"      # Filter out cancelled orders
      enrichment_function = "orders-enrichment"  # Add customer details
      transform_function  = "orders-transformer" # Reshape for downstream systems
      routing_function    = "orders-router"      # Route by region

      destination = {
        type           = "kafka"
        hosts          = var.kafka_hosts
        topic          = "orders.processed" # fallback topic
        tls            = true
        username       = var.kafka_username
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }

      batch_size = 50
    }
  }
}
