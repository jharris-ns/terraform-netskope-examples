# =============================================================================
# AWS Transit Gateway + Netskope IPSec Integration
# =============================================================================
# This example demonstrates a complete deployment:
# 1. Create Netskope IPSec tunnels
# 2. Create AWS Transit Gateway VPN attachments
# 3. Configure routing for traffic steering to Netskope
#
# Architecture:
#   VPCs → Transit Gateway → VPN Connection → Netskope PoP → Internet
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = "~> 0.3.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================

provider "netskope" {
  # Uses NETSKOPE_SERVER_URL and NETSKOPE_API_KEY environment variables
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# =============================================================================
# Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = null
}

variable "tunnel_name_prefix" {
  description = "Prefix for tunnel names"
  type        = string
  default     = "AWS-TGW"
}

variable "primary_pop_name" {
  description = "Primary Netskope POP (short code, e.g., iad2)"
  type        = string
  default     = "iad2"
}

variable "backup_pop_name" {
  description = "Backup Netskope POP (short code, e.g., atl1)"
  type        = string
  default     = "atl1"
}

variable "pre_shared_key" {
  description = "IPSec pre-shared key"
  type        = string
  sensitive   = true
}

variable "destination_cidrs" {
  description = "CIDR blocks to route through Netskope (e.g., 0.0.0.0/0 for all traffic)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# =============================================================================
# Data Sources - Netskope POPs
# =============================================================================

data "netskope_ip_sec_po_ps_list" "all_pops" {}

locals {
  primary_pop = [for pop in data.netskope_ip_sec_po_ps_list.all_pops.result : pop if pop.pop_name == var.primary_pop_name][0]
  backup_pop  = [for pop in data.netskope_ip_sec_po_ps_list.all_pops.result : pop if pop.pop_name == var.backup_pop_name][0]
}

data "netskope_ip_sec_pop" "primary" {
  pop_id = local.primary_pop.pop_id
}

data "netskope_ip_sec_pop" "backup" {
  pop_id = local.backup_pop.pop_id
}

# =============================================================================
# AWS Customer Gateway - Primary
# =============================================================================
# Represents the Netskope POP as the "customer" from AWS perspective

resource "aws_customer_gateway" "netskope_primary" {
  bgp_asn    = 65000  # Netskope BGP ASN (if using BGP) or any ASN for static
  ip_address = data.netskope_ip_sec_pop.primary.gateway
  type       = "ipsec.1"

  tags = {
    Name        = "Netskope-${var.primary_pop_name}"
    Environment = "production"
    Purpose     = "traffic-steering"
  }
}

resource "aws_customer_gateway" "netskope_backup" {
  bgp_asn    = 65000
  ip_address = data.netskope_ip_sec_pop.backup.gateway
  type       = "ipsec.1"

  tags = {
    Name        = "Netskope-${var.backup_pop_name}"
    Environment = "production"
    Purpose     = "traffic-steering"
  }
}

# =============================================================================
# AWS VPN Connection - Primary
# =============================================================================

resource "aws_vpn_connection" "netskope_primary" {
  customer_gateway_id = aws_customer_gateway.netskope_primary.id
  transit_gateway_id  = aws_ec2_transit_gateway.test.id
  type                = "ipsec.1"

  # Static routing (recommended for Netskope)
  static_routes_only = true

  # Tunnel 1 configuration
  tunnel1_preshared_key = var.pre_shared_key

  # IKE configuration matching Netskope requirements
  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel1_phase1_lifetime_seconds      = 7200

  # IPSec configuration
  tunnel1_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [14]
  tunnel1_phase2_lifetime_seconds      = 3600

  # Tunnel 2 configuration (AWS creates 2 tunnels per VPN connection)
  tunnel2_preshared_key                = var.pre_shared_key
  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_dh_group_numbers      = [14]
  tunnel2_phase1_lifetime_seconds      = 7200
  tunnel2_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_dh_group_numbers      = [14]
  tunnel2_phase2_lifetime_seconds      = 3600

  tags = {
    Name        = "${var.tunnel_name_prefix}-Primary"
    NetskopePOP = var.primary_pop_name
  }
}

resource "aws_vpn_connection" "netskope_backup" {
  customer_gateway_id = aws_customer_gateway.netskope_backup.id
  transit_gateway_id  = aws_ec2_transit_gateway.test.id
  type                = "ipsec.1"
  static_routes_only  = true

  tunnel1_preshared_key                = var.pre_shared_key
  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel1_phase1_lifetime_seconds      = 7200
  tunnel1_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [14]
  tunnel1_phase2_lifetime_seconds      = 3600

  tunnel2_preshared_key                = var.pre_shared_key
  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_dh_group_numbers      = [14]
  tunnel2_phase1_lifetime_seconds      = 7200
  tunnel2_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_dh_group_numbers      = [14]
  tunnel2_phase2_lifetime_seconds      = 3600

  tags = {
    Name        = "${var.tunnel_name_prefix}-Backup"
    NetskopePOP = var.backup_pop_name
  }
}

# =============================================================================
# Netskope IPSec Tunnels
# =============================================================================
# Create tunnels in Netskope that correspond to the AWS VPN connections

resource "netskope_ip_sec_tunnel" "primary_tunnel1" {
  site = "${var.tunnel_name_prefix}-Primary-T1"

  # AWS VPN provides the outside IP for tunnel 1
  source_ip       = aws_vpn_connection.netskope_primary.tunnel1_address
  source_identity = "${var.tunnel_name_prefix}-primary-t1@company.com"

  pop_names  = [var.primary_pop_name, var.backup_pop_name]
  psk        = var.pre_shared_key
  encryption = "AES256-GCM"
  bandwidth  = 250

  options = {
    rekey = true
  }
}

resource "netskope_ip_sec_tunnel" "primary_tunnel2" {
  site = "${var.tunnel_name_prefix}-Primary-T2"

  source_ip       = aws_vpn_connection.netskope_primary.tunnel2_address
  source_identity = "${var.tunnel_name_prefix}-primary-t2@company.com"

  pop_names  = [var.primary_pop_name, var.backup_pop_name]
  psk        = var.pre_shared_key
  encryption = "AES256-GCM"
  bandwidth  = 250

  options = {
    rekey = true
  }
}

resource "netskope_ip_sec_tunnel" "backup_tunnel1" {
  site = "${var.tunnel_name_prefix}-Backup-T1"

  source_ip       = aws_vpn_connection.netskope_backup.tunnel1_address
  source_identity = "${var.tunnel_name_prefix}-backup-t1@company.com"

  pop_names  = [var.backup_pop_name, var.primary_pop_name]
  psk        = var.pre_shared_key
  encryption = "AES256-GCM"
  bandwidth  = 250

  options = {
    rekey = true
  }
}

resource "netskope_ip_sec_tunnel" "backup_tunnel2" {
  site = "${var.tunnel_name_prefix}-Backup-T2"

  source_ip       = aws_vpn_connection.netskope_backup.tunnel2_address
  source_identity = "${var.tunnel_name_prefix}-backup-t2@company.com"

  pop_names  = [var.backup_pop_name, var.primary_pop_name]
  psk        = var.pre_shared_key
  encryption = "AES256-GCM"
  bandwidth  = 250

  options = {
    rekey = true
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "aws_vpn_primary" {
  description = "Primary VPN connection details"
  value = {
    vpn_id          = aws_vpn_connection.netskope_primary.id
    tunnel1_address = aws_vpn_connection.netskope_primary.tunnel1_address
    tunnel2_address = aws_vpn_connection.netskope_primary.tunnel2_address
    netskope_pop    = var.primary_pop_name
    netskope_pop_ip = data.netskope_ip_sec_pop.primary.gateway
  }
}

output "aws_vpn_backup" {
  description = "Backup VPN connection details"
  value = {
    vpn_id          = aws_vpn_connection.netskope_backup.id
    tunnel1_address = aws_vpn_connection.netskope_backup.tunnel1_address
    tunnel2_address = aws_vpn_connection.netskope_backup.tunnel2_address
    netskope_pop    = var.backup_pop_name
    netskope_pop_ip = data.netskope_ip_sec_pop.backup.gateway
  }
}

output "netskope_tunnel_ids" {
  description = "Netskope IPSec tunnel IDs"
  value = {
    primary_t1 = netskope_ip_sec_tunnel.primary_tunnel1.tunnel_id
    primary_t2 = netskope_ip_sec_tunnel.primary_tunnel2.tunnel_id
    backup_t1  = netskope_ip_sec_tunnel.backup_tunnel1.tunnel_id
    backup_t2  = netskope_ip_sec_tunnel.backup_tunnel2.tunnel_id
  }
}

output "next_steps" {
  description = "Post-deployment steps"
  value = <<-EOT

    ============================================================
    DEPLOYMENT COMPLETE - Next Steps:
    ============================================================

    1. Verify tunnel status in AWS Console:
       VPC > Site-to-Site VPN Connections

    2. Verify tunnel status in Netskope Admin Console:
       Settings > Security Cloud Platform > Traffic Steering > IPSec

    3. Configure Transit Gateway routing:
       - Add routes for ${join(", ", var.destination_cidrs)} pointing to VPN attachments
       - Configure TGW route table associations

    4. Create Netskope steering policies:
       - Configure Real-time Protection policies
       - Define app/URL categories for inspection

    5. Test connectivity:
       - Verify traffic flows through Netskope
       - Check Netskope SkopeIT for traffic visibility

    ============================================================
  EOT
}
