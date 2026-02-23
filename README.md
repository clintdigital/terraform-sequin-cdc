# Sequin CDC Terraform module

Terraform module that provisions a complete [Sequin](https://sequinstream.com) Change Data Capture (CDC) pipeline on top of the [clintdigital/sequin](https://registry.terraform.io/providers/clintdigital/sequin/latest) provider.

- Database connection to PostgreSQL via Sequin
- One or more **sink consumers** (Kafka, SQS, Kinesis, Webhook) — created with `for_each` so any number can be managed in a single block
- Optional **backfills** — replay historical rows into a consumer on demand
- Schema and table filtering — include or exclude schemas/tables per consumer
- Per-row transformation, enrichment, routing, and filter function references
- Safe destroy protection via `prevent_destroy`
- Full `for_each` support on the module itself for per-tenant/per-environment patterns

## Usage

### Single consumer (Kafka)

```hcl
module "sequin" {
  source  = "clintdigital/sequin-cdc/sequin"
  version = "~> 1.0"

  database_name = "production-db"
  postgres_host = "db.example.com"
  postgres_db   = "myapp"
  postgres_user = "sequin"
  postgres_pass = var.db_password

  consumers = {
    orders-to-kafka = {
      tables = {
        include = [{ name = "public.orders" }]
      }
      destination = {
        type           = "kafka"
        hosts          = "broker1:9092,broker2:9092"
        topic          = "database.orders"
        tls            = true
        username       = "user"
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }
    }
  }
}
```

### Multiple consumers (Kafka + SQS + Webhook)

```hcl
module "sequin" {
  source  = "clintdigital/sequin-cdc/sequin"
  version = "~> 1.0"

  database_name = "production-db"
  postgres_host = "db.example.com"
  postgres_db   = "myapp"
  postgres_user = "sequin"
  postgres_pass = var.db_password

  consumers = {
    orders-to-kafka = {
      tables = {
        include = [
          { name = "public.orders", group_column_names = ["customer_id"] },
          { name = "public.order_items" }
        ]
      }
      actions          = ["insert", "update"]
      filter_function  = "orders-filter"
      routing_function = "topic-router"

      destination = {
        type           = "kafka"
        hosts          = "broker1:9092"
        topic          = "database.orders"
        tls            = true
        username       = "user"
        password       = var.kafka_password
        sasl_mechanism = "scram_sha_256"
      }

      batch_size       = 10
      message_grouping = true
    }

    events-to-sqs = {
      tables = { include = [{ name = "public.events" }] }

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
      tables = { include = [{ name = "public.notifications" }] }

      destination = {
        type               = "webhook"
        http_endpoint      = "https://api.example.com"
        http_endpoint_path = "/webhooks/sequin"
        batch              = true
      }
    }
  }
}
```

### With backfill

```hcl
module "sequin" {
  source  = "clintdigital/sequin-cdc/sequin"
  version = "~> 1.0"

  database_name = "production-db"
  postgres_host = "db.example.com"
  postgres_db   = "myapp"
  postgres_user = "sequin"
  postgres_pass = var.db_password

  consumers = {
    orders-to-kafka = {
      tables = { include = [{ name = "public.orders" }] }
      destination = {
        type  = "kafka"
        hosts = "broker1:9092"
        topic = "database.orders"
      }
    }
  }

  backfills = {
    orders-initial = {
      consumer_name = "orders-to-kafka"
      tables        = ["public.orders", "public.order_items"] # omit to backfill all tables
      state         = "active"
    }
  }
}
```

### Per-tenant provisioning with `for_each`

```hcl
module "sequin" {
  source   = "clintdigital/sequin-cdc/sequin"
  version  = "~> 1.0"
  for_each = toset(["tenant-a", "tenant-b", "tenant-c"])

  database_name = "${each.key}-db"
  postgres_host = "db.example.com"
  postgres_db   = each.key
  postgres_user = "sequin"
  postgres_pass = var.db_password

  replication_slots = [{
    publication_name = "${each.key}_pub"
    slot_name        = "${each.key}_slot"
  }]

  consumers = {
    "${each.key}-sink" = {
      tables = { include = [{ name = "public.events" }] }
      destination = {
        type  = "kafka"
        hosts = "broker1:9092"
        topic = "${each.key}.events"
      }
    }
  }
}
```

## Schema and table filtering

Each consumer can independently filter which schemas and tables it receives:

```hcl
consumers = {
  # All schemas, all tables (default — omit both keys)
  all = {
    destination = { ... }
  }

  # Only specific tables
  specific = {
    tables = {
      include = [{ name = "public.orders" }, { name = "public.items" }]
    }
    destination = { ... }
  }

  # Whole schema, all tables
  public-only = {
    schemas = { include = ["public"] }
    destination = { ... }
  }

  # All schemas except one
  skip-internal = {
    schemas = { exclude = ["internal"] }
    destination = { ... }
  }

  # Exclude specific tables within an include
  skip-audit = {
    tables = {
      include = [{ name = "public.orders" }]
      exclude = [{ name = "public.audit_log" }]
    }
    destination = { ... }
  }
}
```

## Destination types

| Type | Required fields | Optional fields |
|------|-----------------|-----------------|
| `kafka` | `hosts`, `topic` | `tls`, `username`, `password`, `sasl_mechanism`, `aws_region`, `aws_access_key_id`, `aws_secret_access_key` |
| `sqs` | `queue_url`, `region`, `access_key_id`, `secret_access_key` | `is_fifo` |
| `kinesis` | `stream_arn`, `region`, `access_key_id`, `secret_access_key` | — |
| `webhook` | `http_endpoint` | `http_endpoint_path`, `batch` |

## Function references

`filter_function`, `enrichment_function`, `transform_function`, and `routing_function` accept a **function name string**. The function must be created in the Sequin UI or API before referencing it here — this module does not manage function resources.

## Import existing resources

```bash
# Database
terraform import 'module.sequin.sequin_database.this' <database-id>

# Consumer
terraform import 'module.sequin.sequin_sink_consumer.this["consumer-name"]' <consumer-id>

# Backfill
terraform import 'module.sequin.sequin_backfill.this["backfill-name"]' <sink_consumer_name>/<backfill_id>

# With for_each on the module
terraform import 'module.sequin["tenant-a"].sequin_database.this' <database-id>
```

## Examples

- [basic](examples/basic) — minimal setup: one database, one webhook consumer
- [complete](examples/complete) — database + Kafka, SQS, and Webhook consumers + backfill
- [kinesis](examples/kinesis) — stream changes into Amazon Kinesis Data Streams, with initial backfill
- [multi-tenant](examples/multi-tenant) — one pipeline per tenant using `for_each` on the module
- [with-filtering](examples/with-filtering) — all schema and table filter patterns in one place

<!-- BEGIN_TF_DOCS -->


## Providers

| Name | Version |
|------|---------|
| <a name="provider_sequin"></a> [sequin](#provider\_sequin) | >= 0.1 |

## Resources

| Name | Type |
|------|------|
| [sequin_backfill.this](https://registry.terraform.io/providers/clintdigital/sequin/latest/docs/resources/backfill) | resource |
| [sequin_database.this](https://registry.terraform.io/providers/clintdigital/sequin/latest/docs/resources/database) | resource |
| [sequin_sink_consumer.this](https://registry.terraform.io/providers/clintdigital/sequin/latest/docs/resources/sink_consumer) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Unique name for the Sequin database connection. Used to identify the connection in Sequin and as a reference in sink consumers. | `string` | n/a | yes |
| <a name="input_postgres_db"></a> [postgres\_db](#input\_postgres\_db) | Name of the PostgreSQL database to connect to. | `string` | n/a | yes |
| <a name="input_postgres_host"></a> [postgres\_host](#input\_postgres\_host) | Hostname or IP address of the PostgreSQL server. | `string` | n/a | yes |
| <a name="input_postgres_pass"></a> [postgres\_pass](#input\_postgres\_pass) | PostgreSQL password for the replication user. | `string` | n/a | yes |
| <a name="input_postgres_user"></a> [postgres\_user](#input\_postgres\_user) | PostgreSQL username. The user must have replication privileges. | `string` | n/a | yes |
| <a name="input_backfills"></a> [backfills](#input\_backfills) | Map of backfills to create. The map key is used as the backfill identifier.<br/>Backfills replay historical rows from a table into an existing consumer.<br/><br/>Attributes:<br/>- `consumer_name` (required) — Key of the consumer in `var.consumers` to backfill.<br/>- `tables`        (optional) — List of fully-qualified table names to backfill (e.g. `["public.orders", "public.items"]`). Omit or leave empty to backfill all tables. One `sequin_backfill` resource is created per table entry.<br/>- `state`         (optional) — Initial state: `"active"` to start immediately, `"paused"` to hold. | <pre>map(object({<br/>    consumer_name = string<br/>    tables        = optional(list(string))<br/>    state         = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_consumers"></a> [consumers](#input\_consumers) | Map of sink consumers to create. The map key becomes the consumer name in Sequin.<br/><br/>Filtering (all optional — omit to receive all changes):<br/>- `schemas.include`     — List of schema names to include.<br/>- `schemas.exclude`     — List of schema names to exclude.<br/>- `tables.include`      — List of `{ name, group_column_names? }` objects to include.<br/>- `tables.exclude`      — List of `{ name }` objects to exclude from the include set.<br/>- `actions`             — DML events to capture. Default: `["insert", "update", "delete"]`.<br/>- `filter_function`     — Name of a Sequin filter function (must exist in Sequin beforehand).<br/><br/>Functions (all optional, must exist in Sequin beforehand):<br/>- `enrichment_function` — Enriches each record before delivery.<br/>- `transform_function`  — Transforms the message payload.<br/>- `routing_function`    — Routes messages to different destinations dynamically.<br/><br/>Destination (required):<br/>- `type`                — One of `kafka`, `sqs`, `kinesis`, `webhook`.<br/>- Kafka fields:   `hosts`, `topic`, `tls`, `username`, `password`, `sasl_mechanism`.<br/>- SQS fields:     `queue_url`, `region`, `access_key_id`, `secret_access_key`, `is_fifo`.<br/>- Kinesis fields: `stream_arn`, `region`, `access_key_id`, `secret_access_key`.<br/>- Webhook fields: `http_endpoint`, `http_endpoint_path`, `batch`.<br/><br/>Advanced (all optional):<br/>- `status`               — Consumer status: `"active"` or `"disabled"`.<br/>- `batch_size`           — Number of records per delivery batch.<br/>- `message_grouping`     — Whether to group messages by `group_column_names`.<br/>- `max_retry_count`      — Maximum delivery retry attempts before dead-lettering.<br/>- `load_shedding_policy` — Behaviour when the consumer falls behind: `"pause"` or `"discard"`.<br/>- `timestamp_format`     — Timestamp format in delivered messages. | `any` | `{}` | no |
| <a name="input_postgres_port"></a> [postgres\_port](#input\_postgres\_port) | Port the PostgreSQL server is listening on. | `number` | `5432` | no |
| <a name="input_postgres_ssl"></a> [postgres\_ssl](#input\_postgres\_ssl) | Whether to require SSL for the PostgreSQL connection. | `bool` | `true` | no |
| <a name="input_prevent_destroy"></a> [prevent\_destroy](#input\_prevent\_destroy) | When `true`, Terraform will refuse to destroy the database resource, preventing accidental deletion of the Sequin connection and all its consumers. | `bool` | `true` | no |
| <a name="input_replication_slots"></a> [replication\_slots](#input\_replication\_slots) | Logical replication slot and publication configuration.<br/><br/>Attributes:<br/>- `publication_name` (required) — PostgreSQL publication name.<br/>- `slot_name`        (required) — PostgreSQL replication slot name.<br/>- `status`           (optional) — Slot status. Defaults to `"active"`. | <pre>list(object({<br/>    publication_name = string<br/>    slot_name        = string<br/>    status           = optional(string, "active")<br/>  }))</pre> | <pre>[<br/>  {<br/>    "publication_name": "sequin_pub",<br/>    "slot_name": "sequin_slot"<br/>  }<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backfill_ids"></a> [backfill\_ids](#output\_backfill\_ids) | Map of backfill name to Sequin backfill ID for every backfill created by this module. |
| <a name="output_consumer_ids"></a> [consumer\_ids](#output\_consumer\_ids) | Map of consumer name to Sequin sink consumer ID for every consumer created by this module. |
| <a name="output_database_id"></a> [database\_id](#output\_database\_id) | The ID of the Sequin database connection resource. |
<!-- END_TF_DOCS -->

## Authors

This module is currently being maintained by Igor Zimmer @ [Clint Digital](https://github.com/clintdigital).