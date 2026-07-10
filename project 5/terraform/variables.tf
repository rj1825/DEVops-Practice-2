variable "primary_region" {
  description = "The primary AWS region for active deployments"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "The secondary AWS region for failover and low-latency replicas"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name prefix for resources and tags"
  type        = string
  default     = "global-app"
}

variable "domain_name" {
  description = "Domain name for DNS routing. If empty, Route 53 resources will be skipped."
  type        = string
  default     = ""
}
