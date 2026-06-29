# AIG Examples — Generation Spec

This spec describes the example Terraform configurations to create for the Netskope AI Gateway (AIG) resources in the `terraform-provider-netskope` provider. These examples are intended to live in a separate `terraform-provider-examples` project as runnable end-to-end demos.

## Provider version

Use provider version `~> 0.4.6`.

```hcl
terraform {
  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = "~> 0.4.6"
    }
  }
}

provider "netskope" {
  # NETSKOPE_API_KEY and NETSKOPE_SERVER_URL must be set as env vars
}
```

---

## Resource naming constraints

Some AIG resources enforce name prefixes and length limits enforced by the API:

| Resource | Required prefix | Max length |
|---|---|---|
| `netskope_aig_ai_provider` | `cust-` | 15 chars |
| `netskope_aig_mcp_server` | `mcp-cust-` | 19 chars |
| `netskope_aig_rate_limit` | none | 15 chars |
| `netskope_aig_token_group` | none | 100 chars |
| `netskope_aig_token` | none | 100 chars |
| `netskope_aig_appliance` | none | none |

---

## Examples to create

### 1. `netskope_aig_token_group`

Create this first — tokens depend on it.

**File:** `aig/token-group/main.tf`

```hcl
resource "netskope_aig_token_group" "it_chatbot" {
  name        = "IT ChatBot"
  description = "Tokens for the IT department ChatBot application"
}

output "token_group_id" {
  value = netskope_aig_token_group.it_chatbot.id
}
```

---

### 2. `netskope_aig_token`

Tokens belong to a token group. The actual bearer token string is only available in the create response — Terraform does not re-read it on refresh.

> **Note:** `expire_in` is required by the API even though the OAS marks it optional. Omitting it causes the API to return an error (`expire_in.value must be 1 or greater`). Always set a valid `expire_in`. Valid units: `hour`, `day`, `week`, `month`, `year`. Maximum value: 8760 hours (1 year).

**File:** `aig/token/main.tf`

```hcl
resource "netskope_aig_token_group" "it_chatbot" {
  name        = "IT ChatBot"
  description = "Tokens for the IT department ChatBot"
}

# Long-lived token (1 year)
resource "netskope_aig_token" "long_lived" {
  name           = "IT ChatBot annual key"
  token_group_id = netskope_aig_token_group.it_chatbot.id

  expire_in = {
    unit  = "year"
    value = 1
  }
}

# Token that expires in 24 hours
resource "netskope_aig_token" "short_lived" {
  name           = "IT ChatBot 24h key"
  token_group_id = netskope_aig_token_group.it_chatbot.id

  expire_in = {
    unit  = "hour"
    value = 24
  }
}

output "long_lived_token_id" {
  value = netskope_aig_token.long_lived.id
}

output "short_lived_token_expire_time" {
  value = netskope_aig_token.short_lived.expire_time
}
```

---

### 3. `netskope_aig_ai_provider`

Custom AI provider pointing to an on-premise or private AI backend. Name must start with `cust-` and be ≤15 chars.

**File:** `aig/ai-provider/main.tf`

```hcl
# Custom provider using HTTPS with system CA (e.g. public LLM with TLS)
resource "netskope_aig_ai_provider" "ollama" {
  name     = "cust-ollama"
  host     = "ollama.internal.company.com"
  port     = 443
  protocol = "https-system"
  schema   = "openai"
}

# Custom provider that skips TLS verification (dev/test only)
resource "netskope_aig_ai_provider" "dev_backend" {
  name     = "cust-dev-llm"
  host     = "llm-dev.internal.company.com"
  port     = 8080
  protocol = "http"
  schema   = "openai"
}

output "ollama_provider_id" {
  value = netskope_aig_ai_provider.ollama.id
}
```

---

### 4. `netskope_aig_mcp_server`

Custom MCP server for AI agent tool/resource access. Name must start with `mcp-cust-` and be ≤19 chars.

**File:** `aig/mcp-server/main.tf`

```hcl
# MCP server with no tool/resource/prompt filtering (allow all)
resource "netskope_aig_mcp_server" "github" {
  name     = "mcp-cust-github"
  host     = "api.githubcopilot.com"
  port     = 443
  path     = "/mcp"
  protocol = "https-system"
}

# MCP server with specific tool allowlist
resource "netskope_aig_mcp_server" "restricted" {
  name     = "mcp-cust-jira"
  host     = "mcp.atlassian.internal.company.com"
  port     = 443
  path     = "/mcp"
  protocol = "https-system"

  tools = [
    "create_issue",
    "get_issue",
    "search_issues",
  ]
}

output "github_server_id" {
  value = netskope_aig_mcp_server.github.id
}
```

---

### 5. `netskope_aig_rate_limit`

Rate limit rules control request throughput per appliance. The `criteria.apply_on` field determines whether the rule targets `"ai"` (AI provider) or `"mcp"` (MCP server) traffic.

**File:** `aig/rate-limit/main.tf`

```hcl
resource "netskope_aig_token_group" "it_chatbot" {
  name        = "IT ChatBot"
  description = "Tokens for the IT department ChatBot"
}

resource "netskope_aig_ai_provider" "ollama" {
  name     = "cust-ollama"
  host     = "ollama.internal.company.com"
  port     = 443
  protocol = "https-system"
  schema   = "openai"
}

# AI traffic rate limit: 500 requests/hour for a specific token group and provider
resource "netskope_aig_rate_limit" "corp_gpt" {
  name = "corp-gpt-limit"

  criteria = {
    apply_on = "ai"

    ai_provider_ids = [netskope_aig_ai_provider.ollama.id]

    token_group_ids = [netskope_aig_token_group.it_chatbot.id]

    models = [
      { type = "exact", value = "gpt-4o" },
      { type = "exact", value = "gpt-4o-mini" },
    ]
  }

  limit = {
    requests = 500
    unit     = "hour"
  }

  response = "Rate limit exceeded. Please try again later."
}

# Broad AI rate limit across all providers (no filtering)
resource "netskope_aig_rate_limit" "global_ai" {
  name = "global-ai"

  criteria = {
    apply_on = "ai"
  }

  limit = {
    requests = 10000
    unit     = "day"
  }
}
```

---

### 6. `netskope_aig_appliance`

The AIG appliance is the on-premise proxy gateway. After creation it must be registered via the enrollment token flow.

**File:** `aig/appliance/main.tf`

```hcl
resource "netskope_aig_ai_provider" "ollama" {
  name     = "cust-ollama"
  host     = "ollama.internal.company.com"
  port     = 443
  protocol = "https-system"
  schema   = "openai"
}

resource "netskope_aig_appliance" "hq" {
  name = "hq-aig-01"
  host = "aig-hq.internal.company.com"

  ai_provider_ids = [netskope_aig_ai_provider.ollama.id]

  ports = {
    http = {
      enable = false
      port   = 80
    }
    https = {
      enable = true
      port   = 443
    }
  }
}

output "appliance_id" {
  value = netskope_aig_appliance.hq.id
}

output "appliance_status" {
  value = netskope_aig_appliance.hq.status
}
```

---

### 7. `netskope_aig_appliance_enrollment_token`

Generates a one-time enrollment token to register the physical/virtual appliance.

**File:** `aig/enrollment-token/main.tf`

```hcl
resource "netskope_aig_appliance" "hq" {
  name = "hq-aig-01"
  host = "aig-hq.internal.company.com"

  ports = {
    http  = { enable = false, port = 80 }
    https = { enable = true, port = 443 }
  }
}

resource "netskope_aig_appliance_enrollment_token" "hq" {
  appliance_id = netskope_aig_appliance.hq.id
}

output "enrollment_token" {
  value     = netskope_aig_appliance_enrollment_token.hq.enrollment_token
  sensitive = true
}

output "token_expires" {
  value = netskope_aig_appliance_enrollment_token.hq.expire_time
}
```

---

### 8. End-to-end example: full AIG setup

A single example that wires everything together in dependency order.

**File:** `aig/full-setup/main.tf`

```hcl
# --- Token group and tokens ---

resource "netskope_aig_token_group" "it_dept" {
  name        = "IT Department"
  description = "API tokens for IT department AI tools"
}

resource "netskope_aig_token" "it_bot" {
  name           = "it-bot-key"
  token_group_id = netskope_aig_token_group.it_dept.id

  expire_in = {
    unit  = "month"
    value = 3
  }
}

# --- AI provider ---

resource "netskope_aig_ai_provider" "ollama" {
  name     = "cust-ollama"
  host     = "ollama.internal.company.com"
  port     = 443
  protocol = "https-system"
  schema   = "openai"
}

# --- MCP server ---

resource "netskope_aig_mcp_server" "github" {
  name     = "mcp-cust-github"
  host     = "api.githubcopilot.com"
  port     = 443
  path     = "/mcp"
  protocol = "https-system"
}

# --- Rate limits ---

resource "netskope_aig_rate_limit" "it-ai" {
  name = "it-ai-limit"

  criteria = {
    apply_on        = "ai"
    ai_provider_ids = [netskope_aig_ai_provider.ollama.id]
    token_group_ids = [netskope_aig_token_group.it_dept.id]
  }

  limit = {
    requests = 1000
    unit     = "hour"
  }
}

# --- Appliance ---

resource "netskope_aig_appliance" "hq" {
  name = "hq-aig-01"
  host = "aig-hq.internal.company.com"

  ai_provider_ids = [netskope_aig_ai_provider.ollama.id]
  mcp_server_ids  = [netskope_aig_mcp_server.github.id]

  ports = {
    http  = { enable = false, port = 80 }
    https = { enable = true, port = 443 }
  }
}

resource "netskope_aig_appliance_enrollment_token" "hq" {
  appliance_id = netskope_aig_appliance.hq.id
}

# --- Outputs ---

output "appliance_id" {
  value = netskope_aig_appliance.hq.id
}

output "enrollment_token" {
  value     = netskope_aig_appliance_enrollment_token.hq.enrollment_token
  sensitive = true
}
```

---

## Data source examples (read-only)

These should also have corresponding `data-source.tf` examples:

| Data source | Lookup by | Notes |
|---|---|---|
| `netskope_aig_appliance` | `id` | Single appliance by UUID |
| `netskope_aig_appliance_list` | none | All appliances |
| `netskope_aig_appliance_capacity_list` | none | Available capacity SKUs |
| `netskope_aig_appliance_image_list` | none | Available appliance firmware images |
| `netskope_aig_ai_provider` | `id` | Single provider |
| `netskope_aig_ai_provider_list` | none | All providers (predefined + custom) |
| `netskope_aig_mcp_server` | `id` | Single MCP server |
| `netskope_aig_mcp_server_list` | none | All MCP servers |
| `netskope_aig_rate_limit` | `id` | Single rate limit rule |
| `netskope_aig_rate_limit_list` | none | All rate limit rules |
| `netskope_aig_token` | `id` | Single token (no token value returned) |
| `netskope_aig_token_list` | none | All tokens |
| `netskope_aig_token_group` | `id` | Single token group |
| `netskope_aig_token_group_list` | none | All token groups |

**Pattern for single-object data sources:**
```hcl
data "netskope_aig_ai_provider" "example" {
  id = "019c88b6-a197-70a2-9122-435a8e4af4cb"
}
```

**Pattern for list data sources (no inputs required):**
```hcl
data "netskope_aig_appliance_list" "all" {}

output "appliance_count" {
  value = length(data.netskope_aig_appliance_list.all.elements)
}
```

---

## File layout

```
aig/
  token-group/
    main.tf
  token/
    main.tf
  ai-provider/
    main.tf
  mcp-server/
    main.tf
  rate-limit/
    main.tf
  appliance/
    main.tf
  enrollment-token/
    main.tf
  full-setup/
    main.tf
```
