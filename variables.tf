variable "database_name" {
  description = "Name for the Sequin database connection."
  type        = string
}

variable "postgres_host" {
  description = "PostgreSQL host address."
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL port."
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
  description = "Enable SSL for the PostgreSQL connection."
  type        = bool
  default     = true
}

variable "replication_slots" {
  description = "Replication slot and publication pairs. Each object requires `publication_name` and `slot_name`; `status` defaults to `\"active\"`."
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
  description = "Map of sink consumers to create (key = consumer name). Each value requires a `destination` object with `type` (`kafka`, `sqs`, `kinesis`, or `webhook`) and its connection fields. Supports optional schema/table filtering, `actions`, function references, and advanced delivery settings. See the README for the full schema."
  type        = any
  default     = {}
}

variable "backfills" {
  description = "Map of backfills to create (key = backfill name). Each value requires `consumer_name`; optionally `tables` (list of fully-qualified table names — omit to backfill all) and `state` (`\"active\"` or `\"paused\"`)."
  type = map(object({
    consumer_name = string
    tables        = optional(list(string))
    state         = optional(string)
  }))
  default = {}
}

variable "prevent_destroy" {
  description = "Prevent accidental destruction of the database resource and all its consumers."
  type        = bool
  default     = true
}
