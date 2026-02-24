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

**Execution order**: When multiple functions are specified, they are applied in this order:
1. `filter_function` — drops messages that don't match criteria
2. `enrichment_function` — adds additional fields to the message
3. `transform_function` — modifies the message structure/content
4. `routing_function` — dynamically chooses the destination topic/queue

See the [with-functions](examples/with-functions) example for practical usage of all four function types.

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
- [with-functions](examples/with-functions) — demonstrates all four function types: filter, enrichment, transform, and routing

<!-- BEGIN_TF_DOCS -->


## Providers

| Name | Version |
|------|---------|
| <a name="provider_sequin"></a> [sequin](#provider\_sequin) | n/a |

## Resources

| Name | Type |
|------|------|
| sequin_backfill.this | resource |
| sequin_database.this | resource |
| sequin_sink_consumer.this | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name for the Sequin database connection. | `string` | n/a | yes |
| <a name="input_postgres_db"></a> [postgres\_db](#input\_postgres\_db) | PostgreSQL database name. | `string` | n/a | yes |
| <a name="input_postgres_host"></a> [postgres\_host](#input\_postgres\_host) | PostgreSQL host address. | `string` | n/a | yes |
| <a name="input_postgres_pass"></a> [postgres\_pass](#input\_postgres\_pass) | PostgreSQL password. | `string` | n/a | yes |
| <a name="input_postgres_user"></a> [postgres\_user](#input\_postgres\_user) | PostgreSQL username. Must have replication privileges. | `string` | n/a | yes |
| <a name="input_backfills"></a> [backfills](#input\_backfills) | Map of backfills to create (key = backfill name). Each value requires consumer\_name; optionally tables (list of fully-qualified table names — omit to backfill all) and state (active or paused). | <pre>map(object({<br/>    consumer_name = string<br/>    tables        = optional(list(string))<br/>    state         = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_consumers"></a> [consumers](#input\_consumers) | Map of sink consumers to create (key = consumer name). Each value requires a destination object with type (kafka, sqs, kinesis, or webhook) and its connection fields. Supports optional schema/table filtering, actions, function references, and advanced delivery settings. See the README for the full schema. | `any` | `{}` | no |
| <a name="input_postgres_port"></a> [postgres\_port](#input\_postgres\_port) | PostgreSQL port. Defaults to 5432. | `number` | `5432` | no |
| <a name="input_postgres_ssl"></a> [postgres\_ssl](#input\_postgres\_ssl) | Enable SSL for the PostgreSQL connection. Set to false only for local or trusted private networks. | `bool` | `true` | no |
| <a name="input_prevent_destroy"></a> [prevent\_destroy](#input\_prevent\_destroy) | When true, Terraform will error if you attempt to destroy the database resource, protecting against accidental deletion. Set to false in non-production environments where teardown is expected. | `bool` | `true` | no |
| <a name="input_replication_slots"></a> [replication\_slots](#input\_replication\_slots) | List of PostgreSQL replication slot and publication pairs to configure on the database. Each object requires publication\_name and slot\_name; status is optional and defaults to active. | <pre>list(object({<br/>    publication_name = string<br/>    slot_name        = string<br/>    status           = optional(string, "active")<br/>  }))</pre> | <pre>[<br/>  {<br/>    "publication_name": "sequin_pub",<br/>    "slot_name": "sequin_slot"<br/>  }<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backfill_ids"></a> [backfill\_ids](#output\_backfill\_ids) | Map of backfill name to Sequin backfill ID for every backfill created by this module. |
| <a name="output_consumer_ids"></a> [consumer\_ids](#output\_consumer\_ids) | Map of consumer name to Sequin sink consumer ID for every consumer created by this module. |
| <a name="output_database_id"></a> [database\_id](#output\_database\_id) | The ID of the Sequin database connection resource. |
<!-- END_TF_DOCS -->

## Authors

This module is currently being maintained by Igor Zimmer @ [Clint Digital](https://github.com/clintdigital).