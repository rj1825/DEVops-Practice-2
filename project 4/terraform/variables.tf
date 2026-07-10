variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for resources"
  type        = string
  default     = "migration-pipeline"
}

variable "db_username" {
  description = "Username for both source and target databases"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Password for both source and target databases"
  type        = string
  sensitive   = true
  default     = "MigrationSecurePass123!"
}
