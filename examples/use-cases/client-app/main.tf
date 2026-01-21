# Client-Based Private Application Example
#
# This example demonstrates how to create a private application that requires
# the Netskope NPA client for access. Ideal for non-HTTP protocols like SSH, RDP,
# or native desktop applications.
#
# Use case: SSH access to servers, RDP to Windows machines, database connections

terraform {
  required_providers {
    netskope = {
      source = "netskopeoss/netskope"
    }
  }
}

provider "netskope" {}

# Look up existing publishers
data "netskope_npa_publishers_list" "all" {}

# Example 1: SSH Server Access
resource "netskope_npa_private_app" "ssh_bastion" {
  private_app_name     = "SSH Bastion Host"
  private_app_hostname = "bastion.internal.company.com"
  private_app_protocol = "ssh"
  real_host            = "10.0.1.100"

  # Client-only access (not browser accessible)
  clientless_access  = false
  is_user_portal_app = false

  # SSH protocol on port 22
  protocols = [
    {
      port     = "22"
      protocol = "tcp"
    }
  ]

  publishers = [
    {
      publisher_id   = tostring(data.netskope_npa_publishers_list.all.data[0].publisher_id)
      publisher_name = data.netskope_npa_publishers_list.all.data[0].publisher_name
    }
  ]

  use_publisher_dns = true
}

# Example 2: RDP Access to Windows Server
resource "netskope_npa_private_app" "rdp_server" {
  private_app_name     = "Windows Admin Server"
  private_app_hostname = "admin-win.internal.company.com"
  private_app_protocol = "rdp"
  real_host            = "10.0.1.200"

  clientless_access  = false
  is_user_portal_app = false

  # RDP protocol on port 3389
  protocols = [
    {
      port     = "3389"
      protocol = "tcp"
    }
  ]

  publishers = [
    {
      publisher_id   = tostring(data.netskope_npa_publishers_list.all.data[0].publisher_id)
      publisher_name = data.netskope_npa_publishers_list.all.data[0].publisher_name
    }
  ]

  use_publisher_dns = true
}

# Example 3: Database Server with Multiple Ports
resource "netskope_npa_private_app" "database_cluster" {
  private_app_name     = "PostgreSQL Database"
  private_app_hostname = "postgres.internal.company.com"
  private_app_protocol = "tcp"
  real_host            = "10.0.2.50"

  clientless_access  = false
  is_user_portal_app = false

  # PostgreSQL default port
  protocols = [
    {
      port     = "5432"
      protocol = "tcp"
    }
  ]

  # Assign to multiple publishers for redundancy
  publishers = [
    {
      publisher_id   = tostring(data.netskope_npa_publishers_list.all.data[0].publisher_id)
      publisher_name = data.netskope_npa_publishers_list.all.data[0].publisher_name
    }
  ]

  use_publisher_dns = true
}

# Outputs
output "ssh_app_hostname" {
  description = "Hostname for SSH access via NPA client"
  value       = netskope_npa_private_app.ssh_bastion.private_app_hostname
}

output "rdp_app_hostname" {
  description = "Hostname for RDP access via NPA client"
  value       = netskope_npa_private_app.rdp_server.private_app_hostname
}

output "database_app_hostname" {
  description = "Hostname for database access via NPA client"
  value       = netskope_npa_private_app.database_cluster.private_app_hostname
}
