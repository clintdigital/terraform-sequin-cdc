resource "sequin_database" "this" {
  name     = var.database_name
  hostname = var.postgres_host
  port     = var.postgres_port
  database = var.postgres_db
  username = var.postgres_user
  password = var.postgres_pass
  ssl      = var.postgres_ssl

  replication_slots = var.replication_slots
}

resource "sequin_sink_consumer" "this" {
  for_each = var.consumers

  name     = each.key
  database = sequin_database.this.name

  dynamic "source" {
    for_each = try(each.value.schemas, null) != null || try(each.value.tables.exclude, null) != null ? [1] : []
    content {
      include_schemas = try(each.value.schemas.include, null)
      exclude_schemas = try(each.value.schemas.exclude, null)
      exclude_tables  = try([for t in each.value.tables.exclude : t.name], null)
    }
  }

  tables = try(each.value.tables.include, [])

  actions    = try(each.value.actions, null)
  filter     = try(each.value.filter_function, null)
  enrichment = try(each.value.enrichment_function, null)
  transform  = try(each.value.transform_function, null)
  routing    = try(each.value.routing_function, null)

  destination = each.value.destination

  status               = try(each.value.status, null)
  batch_size           = try(each.value.batch_size, null)
  message_grouping     = try(each.value.message_grouping, null)
  max_retry_count      = try(each.value.max_retry_count, null)
  load_shedding_policy = try(each.value.load_shedding_policy, null)
  timestamp_format     = try(each.value.timestamp_format, null)

  depends_on = [sequin_database.this]
}

locals {
  # Flatten backfills: one resource per (backfill_name, table) pair.
  # When tables is null or empty, a single entry with table = null is produced (all tables).
  _backfill_entries = merge([
    for name, bf in var.backfills :
    length(coalesce(bf.tables, [])) > 0
    ? { for t in bf.tables : "${name}/${t}" => {
      consumer_name = bf.consumer_name
      table         = t
      state         = bf.state
      }
    }
    : {
      (name) = {
        consumer_name = bf.consumer_name
        table         = null
        state         = bf.state
      }
    }
  ]...)
}

resource "sequin_backfill" "this" {
  for_each = local._backfill_entries

  sink_consumer = sequin_sink_consumer.this[each.value.consumer_name].name
  table         = each.value.table
  state         = each.value.state

  depends_on = [sequin_sink_consumer.this]
}
