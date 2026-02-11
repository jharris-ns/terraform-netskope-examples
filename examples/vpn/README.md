# Netskope IPSec VPN Tunnel Example

Create and manage IPSec VPN tunnels for traffic steering to Netskope's Security Cloud Platform.

## Prerequisites

- Netskope tenant with IPSec/GRE license
- REST API v2 token
- Firewall, router, or VPN gateway with a public IP
- Terraform installed

## Getting Started

### 1. Configure credentials

Set environment variables (recommended):

```bash
export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-v2-token"
```

Or copy the example tfvars and fill in your values:

```bash
cp example.tfvars terraform.tfvars
```

### 2. Initialize

```bash
terraform init
```

### 3. Look up available POPs

Before choosing your tunnel endpoints, discover which POPs are available and closest to your location. Run a plan to see the `available_pops` output:

```bash
terraform plan
```

The `available_pops` output lists all Netskope IPSec POPs with these fields:

| Field | Description |
|-------|-------------|
| `pop_name` | Short code used in configuration (e.g., `iad2`, `atl1`, `sfo1`, `lon1`) |
| `pop_id` | Unique POP identifier |
| `gateway` | Gateway IP address — use this to configure your firewall |
| `location` | Human-readable location (e.g., `Dulles, DC, US`) |
| `region` | Region code (e.g., `US-DC`, `US-GA`) |
| `distance` | Distance from your tenant |
| `bandwidth` | Available bandwidth tiers |
| `accepting_tunnels` | Whether the POP is currently accepting new tunnels |

Choose POPs that are geographically close to your network egress point and have `accepting_tunnels = true`.

### 4. Configure variables

Set your tunnel parameters in `terraform.tfvars`:

```hcl
source_ip        = "203.0.113.50"        # Your firewall's public IP
source_identity  = "vpn@company.com"     # Unique IKE identity per tunnel
pre_shared_key   = "YourStrongPSK123!"   # IPSec PSK
primary_pop_name = "iad2"                # From the POPs list
backup_pop_name  = "atl1"                # Different region for failover
```

### 5. Plan and apply

```bash
terraform plan
terraform apply
```

## Looking Up Resources

### IPSec POPs

List all available POPs:

```hcl
data "netskope_ip_sec_po_ps_list" "all" {}
```

Look up a specific POP by ID (get the `pop_id` from the list above):

```hcl
data "netskope_ip_sec_pop" "example" {
  pop_id = "0x00D9"
}
```

### Existing IPSec Tunnels

List all configured tunnels on your tenant:

```hcl
data "netskope_ip_sec_tunnels_list" "all" {}
```

Look up a specific tunnel by ID:

```hcl
data "netskope_ip_sec_tunnel" "example" {
  tunnel_id = 437
}
```

### GRE POPs and Tunnels

If you are using GRE instead of IPSec, equivalent data sources are available:

```hcl
data "netskope_grepo_ps_list" "all" {}       # List all GRE POPs
data "netskope_grepop" "example" { ... }     # Look up a specific GRE POP
data "netskope_gre_tunnels_list" "all" {}    # List all GRE tunnels
```

## Variables

### Required

| Variable | Description |
|----------|-------------|
| `source_ip` | Public IP of your firewall/router |
| `source_identity` | IKE identity (IP, FQDN, or email) — must be unique per tunnel |
| `pre_shared_key` | IPSec pre-shared key |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `tunnel_name` | `AWS-TGW-Primary` | Site name shown in the Netskope UI |
| `primary_pop_name` | `iad2` | Primary POP short code |
| `backup_pop_name` | `atl1` | Backup POP short code |
| `encryption_cipher` | `AES256-GCM` | `AES128`, `AES256`, `AES128-GCM`, or `AES256-GCM` |
| `max_bandwidth` | `250` | Bandwidth in Mbps: `50`, `100`, `250`, `500`, or `1000` |

## Outputs

| Output | Description |
|--------|-------------|
| `available_pops` | Full list of IPSec POPs with gateway IPs and locations |
| `primary_pop_details` | Gateway IP, location, and name of the primary POP |
| `backup_pop_details` | Gateway IP, location, and name of the backup POP |
| `primary_tunnel_id` | Tunnel ID of the primary tunnel |
| `secondary_tunnel_id` | Tunnel ID of the secondary (backup) tunnel |
| `all_tunnels` | All IPSec tunnels configured on the tenant |

## Provider Schema Reference

The `netskope_ip_sec_tunnel` resource accepts:

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `site` | string | yes | Site name for the tunnel |
| `pop_names` | list(string) | yes | POP short codes (e.g., `["iad2", "atl1"]`) |
| `source_ip` | string | yes | Public IP of your VPN endpoint |
| `source_identity` | string | no | IKE identity — must be unique across all tunnels |
| `psk` | string | no | Pre-shared key |
| `encryption` | string | no | Encryption algorithm |
| `bandwidth` | number | no | Bandwidth limit in Mbps (default: 50) |
| `options` | object | no | `{ rekey = bool, reauth = bool }` |
| `enabled` | bool | no | Enable/disable the tunnel (default: true) |
| `source_type` | string | no | `sdwan`, `firewall`, `router`, or `other` |
| `vendor` | string | no | Network equipment vendor |
| `notes` | string | no | Free-text notes |

## High Availability

This example creates two tunnels for redundancy:

```
Source Device → Primary Tunnel → iad2 (Dulles) + atl1 (Atlanta)
             → Backup Tunnel  → atl1 (Atlanta) + sfo1 (San Francisco)
```

Each tunnel requires a **unique `source_identity`**. The example appends `-backup` to the secondary tunnel's identity automatically.

## Firewall Configuration

After applying, use the output gateway IPs to configure your firewall:

| Parameter | Value |
|-----------|-------|
| IKE Version | IKEv2 |
| Authentication | Pre-Shared Key |
| Encryption | AES-256 or AES-256-GCM |
| Hash | SHA-256 |
| DH Group | 14 or 16 |
| IKE Lifetime | 7200 seconds |
| IPSec Lifetime | 3600 seconds |
| PFS | Group 14 or 16 |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `409 Conflict` on create | Each tunnel needs a unique `source_identity` |
| Tunnel not establishing | Verify source IP, PSK, and that UDP/500 + UDP/4500 are open |
| Tunnel down in Netskope UI | Confirm POP is reachable (ping gateway IP), check IKE logs |
| Traffic not flowing | Verify routing points to tunnel interface, check Netskope policies |

## Resources

- [Netskope Terraform Provider](https://registry.terraform.io/providers/netskopeoss/netskope/latest)
- [Netskope IPSec Documentation](https://docs.netskope.com/en/ipsec/)
- [Configure an IPSec Tunnel](https://docs.netskope.com/en/configure-an-ipsec-tunnel/)
