variable "aws_region" {
  description = "AWS region to deploy the resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for resources and tags"
  type        = string
  default     = "security-remediator"
}

variable "alert_email" {
  description = "Email address to receive auto-remediation security alerts"
  type        = string
  default     = "security-alerts@example.com"
}
