# DNS Security Profile with Security Categories

Creates a DNS Security profile that uses Netskope's threat intelligence categories to block or sinkhole malicious domains.

## What It Creates

- A DNS profile with security category enforcement
- Sinkhole action for malware domains (redirects to a safe IP)
- Block action for phishing and C2 domains (returns NXDOMAIN)
- Allow list for false-positive overrides

## Quick Start

```bash
export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init
terraform apply
```

## How It Works

Security categories use Netskope's real-time threat intelligence to classify domains. You choose the action per category:

| Action | Behavior |
|--------|----------|
| **Block** | Returns NXDOMAIN — the domain appears to not exist |
| **Sinkhole** | Resolves to `sinkhole_ip` — useful for monitoring or serving a block page |

Allow lists take precedence over security categories. If a domain is on the allow list, it is never blocked, even if it matches a blocked category.

## Prerequisites

- Netskope tenant with DNS Security licensed
- REST API v2 access enabled