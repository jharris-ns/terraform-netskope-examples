# DNS Security Profile Examples

Terraform examples for managing [Netskope DNS Security](https://docs.netskope.com/en/dns-security/) profiles.

## Prerequisites

- Netskope tenant with **DNS Security** licensed
- REST API v2 access enabled
- Terraform >= 1.0

## Examples

| Example | Difficulty | Description |
|---------|------------|-------------|
| [basic-profile/](./basic-profile/) | Simple | DNS profile with domain allow and block lists |
| [security-categories/](./security-categories/) | Intermediate | Category-based blocking and sinkholing with threat intelligence |
| [full-deployment/](./full-deployment/) | Advanced | Complete setup: domain config, tunneling detection, custom DNS, inheritance groups |

## Key Concepts

### Domain Lists
- **Allow list** — Trusted domains that bypass all DNS filtering
- **Block list** — Domains that are always blocked

### Security Categories
Netskope classifies domains using real-time threat intelligence. You choose per-category actions:
- **Block** — Returns NXDOMAIN
- **Sinkhole** — Resolves to a configured IP (useful for monitoring or block pages)

### DNS Tunneling Detection
Detects data exfiltration via encoded DNS queries. Supports an allow list for legitimate services with unusual DNS patterns.

### Custom DNS Servers
Route DNS queries through your own infrastructure instead of Netskope's DNS, with optional fallback.

### Inheritance Groups
Assign profiles to organizational groups for hierarchical policy management. Max 1 group per profile.

## Terraform Resources Used

| Resource / Data Source | Description |
|------------------------|-------------|
| `netskope_dns_profile_v2` (resource) | Create and manage DNS profiles |
| `netskope_dns_profile_v2` (data source) | Look up a profile by ID |
| `netskope_dns_profile_v2_list` (data source) | List all DNS profiles |