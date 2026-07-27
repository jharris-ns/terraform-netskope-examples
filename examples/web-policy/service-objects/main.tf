# Service Objects for Real-time Protection Firewall Rules
#
# This example demonstrates how to create named port/protocol profiles
# (service objects) that can be referenced in Real-time Protection firewall
# policy rules.
#
# Use case: Define standard service profiles — HTTPS, DNS, custom application
# ports — as Terraform-managed objects so that firewall rules reference
# a consistent, versioned definition rather than ad-hoc port numbers.
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. Service objects are auto-deployed after create/update. There is no
#    separate deploy step required.
#
# 2. At least one protocol must be set per service object. A service object
#    with no protocols will be rejected by the API.
#
# 3. Port values are strings: single ports ("443") or ranges ("8080-9090").
#    Use tcp_udp for ports that apply to both TCP and UDP.
#
# 4. Predefined (PREDEFINED type) service objects — such as FTP, SMB, SMTP —
#    are Netskope built-ins. They are read-only and can only be looked up
#    via the list data source. Only custom objects can be created.
#
# 5. The API token must have the objects_service API group with rwa permission
#    (deploy requires the 'a' level).
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.4.8"
    }
  }
}

provider "netskope" {}

# =============================================================================
# STANDARD SERVICE OBJECTS
# =============================================================================

# HTTPS — TCP port 443 only
resource "netskope_service_object" "https" {
  name        = "HTTPS"
  description = "Standard HTTPS traffic on TCP 443. Managed by Terraform."
  protocols = {
    tcp = ["443"]
  }
}

# HTTPS including non-standard port used by some internal services
resource "netskope_service_object" "https_extended" {
  name        = "HTTPS-Extended"
  description = "HTTPS on standard and alternate ports. Managed by Terraform."
  protocols = {
    tcp = ["443", "8443"]
  }
}

# DNS — UDP 53 (and TCP 53 for zone transfers / large responses)
resource "netskope_service_object" "dns" {
  name        = "DNS-Custom"
  description = "DNS queries (UDP 53) and zone transfers (TCP 53). Managed by Terraform."
  protocols = {
    tcp_udp = ["53"]
  }
}

# =============================================================================
# CUSTOM APPLICATION SERVICE OBJECTS
# =============================================================================

# Internal web application that runs on a non-standard port range
resource "netskope_service_object" "internal_webapp" {
  name        = "Internal-WebApp-Ports"
  description = "Internal web application — TCP 8080-8090 and 9000. Managed by Terraform."
  protocols = {
    tcp = ["8080-8090", "9000"]
  }
}

# Monitoring and observability tools
resource "netskope_service_object" "monitoring" {
  name        = "Monitoring-Suite"
  description = "Observability stack: Prometheus (9090), Grafana (3000), Jaeger (16686). Managed by Terraform."
  protocols = {
    tcp = ["3000", "9090", "16686"]
  }
}

# ICMP (ping) — for network reachability checks
resource "netskope_service_object" "icmp" {
  name        = "ICMP-Ping"
  description = "ICMP protocol for network reachability. Managed by Terraform."
  protocols = {
    icmp = true
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# Read back one service object by ID
data "netskope_service_object" "https" {
  id         = netskope_service_object.https.id
  depends_on = [netskope_service_object.https]
}

# List all service objects (custom and predefined)
data "netskope_service_object_list" "all" {
  depends_on = [
    netskope_service_object.https,
    netskope_service_object.https_extended,
    netskope_service_object.dns,
    netskope_service_object.internal_webapp,
    netskope_service_object.monitoring,
    netskope_service_object.icmp,
  ]
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  all_service_object_names    = [for s in data.netskope_service_object_list.all.services : s.name]
  custom_service_object_names = [for s in data.netskope_service_object_list.all.services : s.name if s.type == "custom"]
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "service_objects" {
  description = "Service objects created in this configuration"
  value = {
    https = {
      id   = netskope_service_object.https.id
      name = netskope_service_object.https.name
    }
    dns_custom = {
      id   = netskope_service_object.dns.id
      name = netskope_service_object.dns.name
    }
    internal_webapp = {
      id   = netskope_service_object.internal_webapp.id
      name = netskope_service_object.internal_webapp.name
    }
  }
}

output "all_service_object_names" {
  description = "Names of all service objects on this tenant (custom and predefined)"
  value       = local.all_service_object_names
}

output "custom_service_object_names" {
  description = "Names of custom (user-created) service objects only"
  value       = local.custom_service_object_names
}
