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

variable "kafka_hosts" {
  description = "Kafka broker hosts (comma-separated)"
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

variable "aws_access_key_id" {
  description = "AWS access key ID for SQS"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret access key for SQS"
  type        = string
  sensitive   = true
}
