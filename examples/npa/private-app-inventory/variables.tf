# =============================================================================
# Provider Variables
# =============================================================================

variable "netskope_api_key" {
  description = "Netskope API key"
  type        = string
  sensitive   = true
}

variable "netskope_server_url" {
  description = "Netskope server URL (e.g., https://tenant.goskope.com/api/v2)"
  type        = string
}

# =============================================================================
# Application Variables
# =============================================================================

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "primary_publisher_name" {
  description = "Name of the primary publisher to use"
  type        = string
}

variable "secondary_publisher_name" {
  description = "Name of the secondary publisher for HA (optional)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Tags to apply to all applications"
  type        = list(string)
  default     = ["managed-by-terraform"]
}

# Web tier applications
variable "web_apps" {
  description = "Map of web applications to create"
  type = map(object({
    hostname          = string
    real_host         = string
    port              = optional(string, "443")
    clientless_access = optional(bool, true)
    tags              = optional(list(string), [])
  }))
  default = {}
}

# Database applications
variable "database_apps" {
  description = "Map of database applications to create"
  type = map(object({
    hostname  = string
    real_host = string
    port      = string
    protocol  = optional(string, "tcp")
    tags      = optional(list(string), [])
  }))
  default = {}
}

# Infrastructure applications (SSH, RDP, etc.)
variable "infra_apps" {
  description = "Map of infrastructure applications to create"
  type = map(object({
    hostname  = string
    real_host = string
    port      = string
    protocol  = optional(string, "tcp")
    app_type  = optional(string, "ssh") # ssh, rdp, vnc
    tags      = optional(list(string), [])
  }))
  default = {}
}
