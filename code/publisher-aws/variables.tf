# =============================================================================
# Provider Variables
# =============================================================================

variable "netskope_api_key" {
  description = "Netskope API key"
  type        = string
  sensitive   = true
}

variable "netskope_server_url" {
  description = "Netskope server URL"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "AWS SSO profile name"
  type        = string
  default     = "default"
}

# =============================================================================
# Network Variables
# =============================================================================

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.100.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR (for NAT Gateway)"
  type        = string
  default     = "10.100.0.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR (for Publisher)"
  type        = string
  default     = "10.100.1.0/24"
}

# =============================================================================
# Publisher Variables
# =============================================================================

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "publisher_name" {
  description = "Name for the Netskope publisher"
  type        = string
}
