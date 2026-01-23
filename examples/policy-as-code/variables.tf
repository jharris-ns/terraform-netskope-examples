variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# =============================================================================
# User Groups (from your IdP)
# =============================================================================

variable "admin_groups" {
  description = "Groups with admin/infrastructure access (must match groups from your IdP)"
  type        = list(string)
  default     = [] # Empty by default - add your tenant's admin groups
}

variable "developer_groups" {
  description = "Groups with developer access (must match groups from your IdP)"
  type        = list(string)
  default     = [] # Empty by default - add your tenant's developer groups
}

variable "dba_groups" {
  description = "Groups with database access (must match groups from your IdP)"
  type        = list(string)
  default     = [] # Empty by default - add your tenant's DBA groups
}

variable "blocked_groups" {
  description = "Groups explicitly denied access (must match groups from your IdP)"
  type        = list(string)
  default     = [] # Empty by default - add your tenant's blocked groups
}

# =============================================================================
# Application Tags (for rule targeting)
# =============================================================================

variable "web_app_tags" {
  description = "Tags identifying web applications"
  type        = list(string)
  default     = ["web-tier"]
}

variable "database_app_tags" {
  description = "Tags identifying database applications"
  type        = list(string)
  default     = ["database-tier"]
}

variable "infrastructure_app_tags" {
  description = "Tags identifying infrastructure applications"
  type        = list(string)
  default     = ["infrastructure"]
}
