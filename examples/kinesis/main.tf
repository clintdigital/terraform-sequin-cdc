# Kinesis example: stream database changes into Amazon Kinesis Data Streams.
# Each table gets its own consumer so changes are partitioned by table.

module "sequin" {
  source = "../.."

  database_name = "analytics-db"
  postgres_host = var.postgres_host
  postgres_db   = var.postgres_db
  postgres_user = var.postgres_user
  postgres_pass = var.postgres_pass

  consumers = {
    orders-to-kinesis = {
      tables = {
        include = [
          { name = "public.orders", group_column_names = ["customer_id"] },
        ]
      }
      actions = ["insert", "update", "delete"]

      destination = {
        type              = "kinesis"
        stream_arn        = var.kinesis_stream_arn
        region            = var.aws_region
        access_key_id     = var.aws_access_key_id
        secret_access_key = var.aws_secret_access_key
      }

      message_grouping = true
    }

    products-to-kinesis = {
      tables = {
        include = [
          { name = "public.products" },
          { name = "public.product_variants" },
        ]
      }
      actions = ["insert", "update", "delete"]

      destination = {
        type              = "kinesis"
        stream_arn        = var.kinesis_stream_arn
        region            = var.aws_region
        access_key_id     = var.aws_access_key_id
        secret_access_key = var.aws_secret_access_key
      }
    }
  }

  # Backfill existing orders on first deploy
  backfills = {
    orders-initial-load = {
      consumer_name = "orders-to-kinesis"
      tables        = ["public.orders"]
      state         = "active"
    }
  }
}
