variable "database_name" {
  description = "Unique name for the Sequin database connection. Used to identify the connection in Sequin and as a reference in sink consumers."
  type        = string
}

variable "postgres_host" {
  description = "Hostname or IP address of the PostgreSQL server."
  type        = string
}

variable "postgres_port" {
  description = "Port the PostgreSQL server is listening on."
  type        = number
  default     = 5432
}

variable "postgres_db" {
  description = "Name of the PostgreSQL database to connect to."
  type        = string
}

variable "postgres_user" {
  description = "PostgreSQL username. The user must have replication privileges."
  type        = string
}

variable "postgres_pass" {
  description = "PostgreSQL password for the replication user."
  type        = string
  sensitive   = true
}

variable "postgres_ssl" {
  description = "Whether to require SSL for the PostgreSQL connection."
  type        = bool
  default     = true
}

variable "replication_slots" {
  description = <<-EOT
    Logical replication slot and publication configuration.

    Attributes:
    - `publication_name` (required) — PostgreSQL publication name.
    - `slot_name`        (required) — PostgreSQL replication slot name.
    - `status`           (optional) — Slot status. Defaults to `"active"`.
  EOT
  type = list(object({
    publication_name = string
    slot_name        = string
    status           = optional(string, "active")
  }))
  default = [{
    publication_name = "sequin_pub"
    slot_name        = "sequin_slot"
  }]
}

variable "consumers" {
  description = <<-EOT
    Map of sink consumers to create. The map key becomes the consumer name in Sequin.

    Filtering (all optional — omit to receive all changes):
    - `schemas.include`     — List of schema names to include.
    - `schemas.exclude`     — List of schema names to exclude.
    - `tables.include`      — List of `{ name, group_column_names? }` objects to include.
    - `tables.exclude`      — List of `{ name }` objects to exclude from the include set.
    - `actions`             — DML events to capture. Default: `["insert", "update", "delete"]`.
    - `filter_function`     — Name of a Sequin filter function (must exist in Sequin beforehand).

    Functions (all optional, must exist in Sequin beforehand):
    - `enrichment_function` — Enriches each record before delivery.
    - `transform_function`  — Transforms the message payload.
    - `routing_function`    — Routes messages to different destinations dynamically.

    Destination (required):
    - `type`                — One of `kafka`, `sqs`, `kinesis`, `webhook`.
    - Kafka fields:   `hosts`, `topic`, `tls`, `username`, `password`, `sasl_mechanism`.
    - SQS fields:     `queue_url`, `region`, `access_key_id`, `secret_access_key`, `is_fifo`.
    - Kinesis fields: `stream_arn`, `region`, `access_key_id`, `secret_access_key`.
    - Webhook fields: `http_endpoint`, `http_endpoint_path`, `batch`.

    Advanced (all optional):
    - `status`               — Consumer status: `"active"` or `"disabled"`.
    - `batch_size`           — Number of records per delivery batch.
    - `message_grouping`     — Whether to group messages by `group_column_names`.
    - `max_retry_count`      — Maximum delivery retry attempts before dead-lettering.
    - `load_shedding_policy` — Behaviour when the consumer falls behind: `"pause"` or `"discard"`.
    - `timestamp_format`     — Timestamp format in delivered messages.
  EOT
  type        = any
  default     = {}
}

variable "backfills" {
  description = <<-EOT
    Map of backfills to create. The map key is used as the backfill identifier.
    Backfills replay historical rows from a table into an existing consumer.

    Attributes:
    - `consumer_name` (required) — Key of the consumer in `var.consumers` to backfill.
    - `tables`        (optional) — List of fully-qualified table names to backfill (e.g. `["public.orders", "public.items"]`). Omit or leave empty to backfill all tables. One `sequin_backfill` resource is created per table entry.
    - `state`         (optional) — Initial state: `"active"` to start immediately, `"paused"` to hold.
  EOT
  type = map(object({
    consumer_name = string
    tables        = optional(list(string))
    state         = optional(string)
  }))
  default = {}
}

variable "prevent_destroy" {
  description = "When `true`, Terraform will refuse to destroy the database resource, preventing accidental deletion of the Sequin connection and all its consumers."
  type        = bool
  default     = true
}
