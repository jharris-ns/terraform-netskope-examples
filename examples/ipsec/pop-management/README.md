# Netskope IPSec POP Management

Discover available Netskope Points of Presence (POPs) and create a basic IPSec tunnel. POPs are Netskope-managed infrastructure — this example shows how to list and inspect them using data sources, select the right endpoint for your location, and then create a tunnel.

## What it creates

- **1 IPSec tunnel** at the selected Netskope POP

## What it reads (data sources)

- All available IPSec POPs with gateway IPs and status
- Full details for the selected POP
- All configured tunnels (after creation)

## Prerequisites

- Netskope tenant with **IPSec/GRE license** enabled
- REST API v2 token
- Firewall, router, or SD-WAN appliance with a public IP

## Getting Started

### 1. Configure credentials

```bash
export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-v2-token"
```

### 2. Initialize

```bash
terraform init
```

### 3. Discover available POPs

Run a plan to see which POPs are available before choosing your endpoint:

```bash
terraform plan -var='source_ip=0.0.0.0' -var='source_identity=placeholder' -var='pre_shared_key=placeholder'
```

The `accepting_pops` output lists every POP currently accepting new tunnels:

| Field | Description |
|-------|-------------|
| `pop_name` | Short code used in configuration (e.g., `iad2`, `atl1`, `sfo1`, `lon1`) |
| `location` | Human-readable city/region (e.g., `Dulles, DC, US`) |
| `region` | Region code (e.g., `US-DC`, `US-GA`) |
| `gateway` | POP gateway IP — configure this as the remote peer on your firewall |

Choose a POP geographically close to your network egress point.

### 4. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values
```

Key variables:

| Variable | Description |
|----------|-------------|
| `pop_name` | POP short code from the `accepting_pops` output (e.g., `iad2`) |
| `source_ip` | Public IP of your firewall or router |
| `source_identity` | Unique IKE identity per tunnel (IP, FQDN, or email format) |
| `pre_shared_key` | PSK for IKE authentication |

### 5. Apply

```bash
terraform apply
```

### 6. Configure your firewall

After applying, use the `selected_pop_details` output to configure your firewall:

| IKE Parameter | Value |
|---------------|-------|
| Version | IKEv2 |
| Authentication | Pre-Shared Key (from `pre_shared_key` variable) |
| Remote peer IP | `selected_pop_details.gateway` |
| Encryption | AES-256-GCM |
| Hash | SHA-256 |
| DH Group | 14 or 16 |
| IKE Lifetime | 7200 seconds |
| IPSec Lifetime | 3600 seconds |
| PFS | Group 14 or 16 |

Use `selected_pop_details.probe_ip` to test reachability before the tunnel is up:

```bash
ping <probe_ip>
```

## Understanding POPs

POPs are Netskope-managed gateway nodes. You cannot create or delete them — you select them when creating a tunnel. Key attributes:

- **`accepting_tunnels`** — whether the POP is currently accepting new tunnels. Always choose a POP where this is `true`.
- **`gateway`** — the IP address your firewall connects to (the IKE/IPSec remote peer).
- **`probe_ip`** — a separate IP for connectivity testing before the tunnel is established.
- **`bandwidth`** — available bandwidth tiers at this POP.

## Failover

To add automatic failover, include a second POP in `pop_names`:

```hcl
pop_names = ["iad2", "atl1"]
```

Netskope will automatically fail over to the second POP if the primary becomes unavailable.

## Data Sources Reference

### List all POPs

```hcl
data "netskope_ip_sec_po_ps_list" "all" {}
```

Returns `result` (list of POPs) and `total` (count).

### Look up a specific POP by ID

```hcl
data "netskope_ip_sec_pop" "example" {
  pop_id = "0x00D9"
}
```

Returns: `pop_name`, `gateway`, `probe_ip`, `location`, `region`, `bandwidth`, `accepting_tunnels`, `distance`.

### List all tunnels

```hcl
data "netskope_ip_sec_tunnels_list" "all" {}
```

Returns `result` (list of tunnels with `pop_names`) and `total`.

## Outputs

| Output | Description |
|--------|-------------|
| `available_pops_count` | Total IPSec POPs available on this tenant |
| `accepting_pops` | POPs currently accepting tunnels — with location and gateway |
| `selected_pop_details` | Gateway IP, probe IP, and location of the tunnel's POP |
| `tunnel_id` | ID of the created tunnel (use for `netskope_ip_sec_tunnel` data source) |
| `total_tunnels` | Total IPSec tunnels now configured on this tenant |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `index out of range` error | The `pop_name` variable doesn't match any POP — check `accepting_pops` output |
| `409 Conflict` on create | `source_identity` must be unique across all tunnels on this tenant |
| Tunnel not establishing | Verify `source_ip`, PSK match, and UDP/500 + UDP/4500 are open outbound |
| POP unreachable | Ping `selected_pop_details.probe_ip` to test basic connectivity to the POP |

## Resources

- [Netskope Terraform Provider](https://registry.terraform.io/providers/netskopeoss/netskope/latest)
- [Netskope IPSec Documentation](https://docs.netskope.com/en/ipsec/)
- [Configure an IPSec Tunnel](https://docs.netskope.com/en/configure-an-ipsec-tunnel/)
