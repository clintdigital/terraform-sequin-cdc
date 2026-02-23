variable "sequin_endpoint" {
  description = "Sequin API endpoint URL"
  type        = string
}

variable "sequin_api_key" {
  description = "Sequin API key"
  type        = string
  sensitive   = true
}

variable "postgres_host" {
  description = "PostgreSQL host"
  type        = string
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
}

variable "postgres_pass" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "webhook_endpoint" {
  description = "Webhook URL to receive CDC events"
  type        = string
}
