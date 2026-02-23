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

variable "sqs_queue_url" {
  description = "AWS SQS queue URL"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key_id" {
  description = "AWS access key ID"
  type        = string
}

variable "aws_secret_access_key" {
  description = "AWS secret access key"
  type        = string
  sensitive   = true
}

variable "webhook_endpoint" {
  description = "Webhook endpoint URL"
  type        = string
}
