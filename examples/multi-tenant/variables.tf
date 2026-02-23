variable "sequin_endpoint" {
  description = "Sequin API endpoint URL"
  type        = string
}

variable "sequin_api_key" {
  description = "Sequin API key"
  type        = string
  sensitive   = true
}

variable "tenants" {
  description = "Map of tenant name → PostgreSQL connection details"
  type = map(object({
    postgres_host = string
    postgres_db   = string
    postgres_user = string
    postgres_pass = string
  }))
}

variable "kafka_hosts" {
  description = "Kafka broker hosts (comma-separated), shared across all tenants"
  type        = string
}

variable "kafka_username" {
  description = "Kafka username"
  type        = string
}

variable "kafka_password" {
  description = "Kafka password"
  type        = string
  sensitive   = true
}
