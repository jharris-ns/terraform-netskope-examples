# =============================================================================
# AWS Transit Gateway + Netskope IPSec Integration Variables
# =============================================================================
# Copy this file to terraform.tfvars and update with your values.
# IMPORTANT: Never commit terraform.tfvars to version control if it contains
# sensitive values like API keys or pre-shared keys.
# =============================================================================

# AWS Configuration
aws_region  = "us-east-1"
aws_profile = "your-aws-profile"

# Tunnel Naming
# Prefix used for all tunnel and resource names
tunnel_name_prefix = "AWS-TGW"

# Netskope POP Selection
# POP names use short codes (e.g., iad2, atl1, sfo1, lon1)
# Run `terraform plan` to see available POPs in the available_pops output
primary_pop_name = "iad2"
backup_pop_name  = "atl1"

# Pre-Shared Key (PSK) for IPSec authentication
# Use a strong, unique PSK — minimum 16 characters recommended
# This PSK is shared between AWS VPN connections and Netskope tunnels
pre_shared_key = "YourStrongPreSharedKey123!"

# Destination CIDRs
# CIDR blocks to route through Netskope via the Transit Gateway
# Use ["0.0.0.0/0"] to route all traffic
destination_cidrs = ["0.0.0.0/0"]
