# Filtering example: demonstrates every schema and table filter pattern.
# All consumers share the same database but each watches a different slice of it.

module "sequin" {
  source = "../.."

  database_name = "shop-db"
  postgres_host = var.postgres_host
  postgres_db   = var.postgres_db
  postgres_user = var.postgres_user
  postgres_pass = var.postgres_pass

  consumers = {
    # 1. Only specific tables, with column-based grouping for ordering guarantees
    orders-and-items = {
      tables = {
        include = [
          {
            name               = "public.orders",
            group_column_names = ["customer_id"]
          },
          {
            name               = "public.order_items",
            group_column_names = ["order_id"]
          },
        ]
      }
      actions = ["insert", "update", "delete"]

      destination = {
        type           = "kafka"
        hosts          = var.kafka_hosts
        topic          = "cdc.orders"
        tls            = true
        username       = var.kafka_username
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }
    }

    # 2. Entire schema — every table under "inventory"
    inventory-schema = {
      schemas = {
        include = ["inventory"]
      }

      destination = {
        type           = "kafka"
        hosts          = var.kafka_hosts
        topic          = "cdc.inventory"
        tls            = true
        username       = var.kafka_username
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }
    }

    # 3. All schemas except "internal" and "audit"
    skip-internal = {
      schemas = {
        exclude = ["internal", "audit"]
      }

      destination = {
        type           = "kafka"
        hosts          = var.kafka_hosts
        topic          = "cdc.all-public"
        tls            = true
        username       = var.kafka_username
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }
    }

    # 4. Specific tables with excluded tables in the same schema
    public-skip-audit = {
      tables = {
        include = [
          {
            name = "public.users"
          },
          {
            name = "public.accounts"
          },
          {
            name = "public.sessions"
          },
        ]
        exclude = [
          {
            name = "public.sessions"
          },
        ]
      }
      actions = ["insert", "delete"]

      destination = {
        type           = "kafka"
        hosts          = var.kafka_hosts
        topic          = "cdc.users"
        tls            = true
        username       = var.kafka_username
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }
    }
  }

  backfills = {
    # Backfill specific tables per consumer
    orders-backfill = {
      consumer_name = "orders-and-items"
      tables        = ["public.orders", "public.order_items"]
      state         = "active"
    }

    users-backfill = {
      consumer_name = "public-skip-audit"
      tables        = ["public.users", "public.accounts"]
      state         = "active"
    }

    # Backfill all tables in the inventory schema consumer (tables omitted)
    inventory-backfill = {
      consumer_name = "inventory-schema"
      state         = "active"
    }
  }
}
