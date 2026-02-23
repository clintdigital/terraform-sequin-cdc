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

variable "kinesis_stream_arn" {
  description = "ARN of the Kinesis Data Stream"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the Kinesis stream lives"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key_id" {
  description = "AWS access key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret access key"
  type        = string
  sensitive   = true
}
