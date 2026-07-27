# Service Objects

Define named port/protocol profiles that firewall rules in Real-time Protection policies can reference by name.

**Difficulty:** Simple
**Provider version:** >= 0.4.8

## Overview

Service objects are reusable port/protocol definitions. Instead of specifying raw port numbers in every firewall rule, you define the service once and reference it by name — the same pattern used in traditional firewall management.

Without Terraform support, service objects had to be created and updated in the Netskope UI, leaving them outside your IaC workflow.

## Quick Start

```bash
cd examples/web-policy/service-objects

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init && terraform plan
```

## What This Creates

| Service Object | Protocols | Ports |
|---------------|-----------|-------|
| `HTTPS` | TCP | 443 |
| `HTTPS-Extended` | TCP | 443, 8443 |
| `DNS` | TCP+UDP | 53 |
| `Internal-WebApp-Ports` | TCP | 8080-8090, 9000 |
| `Monitoring-Suite` | TCP | 3000, 9090, 16686 |
| `ICMP-Ping` | ICMP | — |

## Key Patterns

### Single Port

```hcl
resource "netskope_service_object" "https" {
  name        = "HTTPS"
  description = "Standard HTTPS."
  protocols = {
    tcp = ["443"]
  }
}
```

### Port Range

```hcl
resource "netskope_service_object" "ephemeral" {
  name        = "Ephemeral-Ports"
  description = "Ephemeral port range for return traffic."
  protocols = {
    tcp_udp = ["1024-65535"]
  }
}
```

### Multiple Protocols

```hcl
resource "netskope_service_object" "web" {
  name        = "Web-HTTP-HTTPS"
  description = "HTTP and HTTPS traffic."
  protocols = {
    tcp = ["80", "443"]
  }
}
```

### ICMP

```hcl
resource "netskope_service_object" "ping" {
  name        = "ICMP-Ping"
  description = "Network reachability."
  protocols = {
    icmp = true
  }
}
```

### TCP+UDP Combined

Use `tcp_udp` when the same port applies to both protocols:

```hcl
resource "netskope_service_object" "dns" {
  name        = "DNS"
  description = "DNS queries and zone transfers."
  protocols = {
    tcp_udp = ["53"]
  }
}
```

## Protocol Fields

| Field | Type | Description |
|-------|------|-------------|
| `icmp` | bool | Enable ICMP |
| `tcp` | list(string) | TCP ports or ranges |
| `udp` | list(string) | UDP ports or ranges |
| `tcp_udp` | list(string) | Both TCP and UDP |

At least one field must be set. Port values are strings: `"443"` for a single port, `"8080-9090"` for a range.

## Predefined Service Objects

Netskope ships with built-in service objects (FTP, SMB, SMTP, etc.) that are read-only. You can see them with:

```hcl
data "netskope_service_object_list" "all" {}

output "predefined" {
  value = [for s in data.netskope_service_object_list.all.services : s.name if s.type == "PREDEFINED"]
}
```

## Common Mistakes

| Mistake | What Happens | Fix |
|---------|--------------|-----|
| No protocols set | API returns 400 | Set at least one protocol field |
| Port as integer (`443`) | Type error in plan | Port values must be strings (`"443"`) |
| Duplicate name | API returns 400 | Service object names must be unique |
| Missing API group permission | 403 error | Token needs `objects_service` with `rwa` |

## Cleanup

```bash
terraform destroy
```

Service objects referenced in active firewall rules must be removed from those rules before they can be deleted.

## Related Examples

- [custom-categories/](../custom-categories/) — Combine URL lists into policy objects
- [npa/rbac-roles/](../../npa/rbac-roles/) — Admin role definitions
