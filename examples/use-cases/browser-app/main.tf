# Browser-Based Private Application Example
#
# This example demonstrates how to create a browser-accessible private application
# that users can access through the Netskope web portal without requiring the NPA client.
#
# Use case: Internal web applications like wikis, dashboards, or admin panels
# that should be accessible via browser from anywhere.

terraform {
  required_providers {
    netskope = {
      source = "netskopeoss/netskope"
    }
  }
}

provider "netskope" {
  # Configure via environment variables:
  # NETSKOPE_SERVER_URL = "https://your-tenant.goskope.com/api/v2"
  # NETSKOPE_API_KEY    = "your-api-token"
}

# Look up existing publishers to assign to the app
data "netskope_npa_publishers_list" "all" {}

# Create a browser-accessible private application
resource "netskope_npa_private_app" "internal_wiki" {
  private_app_name     = "Internal Wiki"
  private_app_hostname = "wiki.internal.company.com"
  private_app_protocol = "https"
  real_host            = "192.168.10.50"

  # Enable browser/clientless access
  clientless_access  = true
  is_user_portal_app = true

  # Protocol configuration for HTTPS
  protocols = [
    {
      port     = "443"
      protocol = "tcp"
    }
  ]

  # Assign to publisher(s) - use the first available publisher
  publishers = [
    {
      publisher_id   = tostring(data.netskope_npa_publishers_list.all.data[0].publisher_id)
      publisher_name = data.netskope_npa_publishers_list.all.data[0].publisher_name
    }
  ]

  # Security settings
  trust_self_signed_certs = false
  use_publisher_dns       = true
}

# Output the public URL for browser access
output "browser_access_url" {
  description = "URL for accessing the application via browser"
  value       = netskope_npa_private_app.internal_wiki.app_url
}

output "app_id" {
  description = "The ID of the created private application"
  value       = netskope_npa_private_app.internal_wiki.id
}
