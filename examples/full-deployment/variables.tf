variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "datacenter_name" {
  description = "Name of the datacenter"
  type        = string
  default     = "us-west-dc1"
}
