# Complete DNS Security Deployment

End-to-end DNS Security setup with all configuration options: domain filtering, security categories, DNS tunneling detection, custom DNS servers, and inheritance group assignment.

## What It Creates

- A fully configured DNS Security profile with:
  - Domain allow and block lists
  - Security category enforcement (Malware, Phishing, C2, Botnet)
  - Sinkhole IP for redirecting malicious domains
  - DNS tunneling detection with allow list
  - Custom DNS server routing with fallback
  - Optional inheritance group assignment

## Quick Start

```bash
export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

# Optional: customize variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

terraform init
terraform apply
```

## How It Works

This example combines all DNS profile capabilities:

1. **Domain config** — Static allow/block lists for specific FQDNs, plus security categories for threat-intelligence-based filtering
2. **Tunnel config** — Detects DNS tunneling (data exfiltration via DNS queries) with an allow list for legitimate high-volume DNS services
3. **Custom config** — Routes DNS queries through your own internal DNS servers instead of Netskope's, with optional fallback
4. **Inheritance groups** — Assigns the profile to an organizational group for policy inheritance

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `profile_name` | Name for the DNS profile | `Full DNS Security Profile` |
| `sinkhole_ip` | IP for sinkholed domains | `198.51.100.1` |
| `custom_dns_servers` | Custom DNS server IPs | `["10.0.0.53", "10.0.1.53"]` |
| `inheritance_group` | Inheritance group name (null to skip) | `null` |

## Prerequisites

- Netskope tenant with DNS Security licensed
- REST API v2 access enabled
- For inheritance group assignment: the group must already exist in your tenant