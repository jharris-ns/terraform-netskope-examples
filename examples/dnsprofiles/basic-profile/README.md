# Basic DNS Security Profile

Creates a DNS Security profile with domain allow and block lists.

## What It Creates

- A DNS profile with traffic logging enabled
- Allow list entries for trusted domains (bypass filtering)
- Block list entries for known-bad domains

## Quick Start

```bash
export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init
terraform apply
```

## How It Works

The profile uses two types of domain lists:

- **Allow list** — Trusted domains that bypass DNS security filtering entirely. Use for internal services or known-good partners.
- **Block list** — Domains that are always blocked regardless of category classification. Use for known-bad domains.

The example also demonstrates the two DNS profile data sources:
- `netskope_dns_profile_v2_list` — list all profiles in the tenant
- `netskope_dns_profile_v2` — look up a specific profile by ID

## Prerequisites

- Netskope tenant with DNS Security licensed
- REST API v2 access enabled