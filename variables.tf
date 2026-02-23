variable "database_name" {
  description = "Name for the Sequin database connection."
  type        = string
}

variable "postgres_host" {
  description = "PostgreSQL host address."
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL port. Defaults to 5432."
  type        = number
  default     = 5432
}

variable "postgres_db" {
  description = "PostgreSQL database name."
  type        = string
}

variable "postgres_user" {
  description = "PostgreSQL username. Must have replication privileges."
  type        = string
}

variable "postgres_pass" {
  description = "PostgreSQL password."
  type        = string
  sensitive   = true
}

variable "postgres_ssl" {
  description = "Enable SSL for the PostgreSQL connection. Set to false only for local or trusted private networks."
  type        = bool
  default     = true
}

variable "replication_slots" {
  description = "List of PostgreSQL replication slot and publication pairs to configure on the database. Each object requires publication_name and slot_name; status is optional and defaults to active."
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
  description = "Map of sink consumers to create (key = consumer name). Each value requires a destination object with type (kafka, sqs, kinesis, or webhook) and its connection fields. Supports optional schema/table filtering, actions, function references, and advanced delivery settings. See the README for the full schema."
  type        = any
  default     = {}
}

variable "backfills" {
  description = "Map of backfills to create (key = backfill name). Each value requires consumer_name; optionally tables (list of fully-qualified table names — omit to backfill all) and state (active or paused)."
  type = map(object({
    consumer_name = string
    tables        = optional(list(string))
    state         = optional(string)
  }))
  default = {}
}

variable "prevent_destroy" {
  description = "When true, Terraform will error if you attempt to destroy the database resource, protecting against accidental deletion. Set to false in non-production environments where teardown is expected."
  type        = bool
  default     = true
}
