# =============================================================================
# Netskope IPSec Tunnel Configuration Variables
# =============================================================================
# Copy this file to terraform.tfvars and update with your values.
# IMPORTANT: Never commit terraform.tfvars to version control if it contains
# sensitive values like API keys or pre-shared keys.
# =============================================================================

# Netskope Tenant Configuration
# Alternatively, use environment variables:
#   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
#   export NETSKOPE_API_KEY="your-api-token"
netskope_server_url = "https://your-tenant.goskope.com/api/v2"
netskope_api_key    = "your-api-v2-token"

# Tunnel Configuration
# Site name used to identify this tunnel in the Netskope UI
tunnel_name = "AWS-TGW-to-Netskope"

# Source Configuration - Your Firewall/Router
# This should be the public IP address of your VPN gateway device
source_ip = "203.0.113.50"

# Source Identity for IKE authentication
# Options:
#   - IP address: "203.0.113.50"
#   - FQDN: "vpn-gateway.acme.com"
#   - Email format: "aws-tgw@acme.com"
# NOTE: Each tunnel requires a unique source_identity
source_identity = "aws-tgw@acme.com"

# Pre-Shared Key (PSK) for IPSec authentication
# Use a strong, unique PSK for each tunnel
# Minimum 16 characters recommended
pre_shared_key = "YourStrongPreSharedKey123!"

# Netskope POP Selection
# POP names use short codes (e.g., iad2, atl1, sfo1, lon1)
# Run `terraform plan` to see the available_pops output for all POP codes
# Choose POPs geographically closest to your network egress point
primary_pop_name = "iad2"
backup_pop_name  = "atl1"

# Encryption Settings
# Options: AES128, AES256, AES128-GCM, AES256-GCM
# AES256-GCM recommended for best performance and security
encryption_cipher = "AES256-GCM"

# Maximum Bandwidth (Mbps)
# Options: 50, 100, 250, 500, 1000
# Contact Netskope to enable 1 Gbps if not available
max_bandwidth = 250

