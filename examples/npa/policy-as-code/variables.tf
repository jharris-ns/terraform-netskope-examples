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

variable "block_template" {
  description = "Display name of the NPA block page template (Settings > Security Cloud Platform > NPA > Block Templates). Must be the display name, not the file name."
  type        = string
  default     = "Generic Block"
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

# =============================================================================
# Device Classification (requires provider >= 0.4.2)
# =============================================================================

variable "required_device_tags" {
  description = "Device classification tag names required for posture-based rules (must exist in Settings > Device Classification)"
  type        = list(string)
  default     = [] # Empty by default - add your tenant's device classification tag names
}
