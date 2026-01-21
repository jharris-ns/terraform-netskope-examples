# Netskope NPA Terraform Provider - Use Case Examples

This directory contains comprehensive examples demonstrating common Netskope NPA deployment scenarios.

## Examples Overview

### [browser-app](./browser-app/)
Create a browser-accessible private application that users can access through the Netskope web portal without requiring the NPA client.

**Best for:** Internal web applications like wikis, dashboards, or admin panels.

### [client-app](./client-app/)
Create private applications that require the Netskope NPA client for access. Includes examples for SSH, RDP, and database connections.

**Best for:** Non-HTTP protocols like SSH, RDP, or native desktop applications.

### [full-deployment](./full-deployment/)
A comprehensive example showing a complete NPA deployment including publishers, private applications (both browser and client-based), and access policies.

**Best for:** Setting up NPA for a new datacenter or application environment.

### [publisher-management](./publisher-management/)
Demonstrates publisher lifecycle management including upgrade profiles, alerts configuration, and multi-region deployments.

**Best for:** Managing a fleet of NPA publishers across multiple locations.

### [policy-rules](./policy-rules/)
Shows NPA policy configuration including policy groups, access rules with various conditions, and rule prioritization.

**Best for:** Implementing zero trust access policies for private applications.

## Getting Started

1. Configure your Netskope credentials:
   ```bash
   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
   export NETSKOPE_API_KEY="your-api-token"
   ```

2. Navigate to the example directory:
   ```bash
   cd browser-app  # or any other example
   ```

3. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Prerequisites

- Terraform >= 1.0
- Netskope tenant with NPA enabled
- API token with appropriate permissions
- At least one registered NPA publisher (for most examples)

## Common Patterns

### Looking Up Existing Resources

```hcl
# Get all publishers
data "netskope_npa_publishers_list" "all" {}

# Get all private apps
data "netskope_npa_private_apps_list" "all" {}

# Get all policy groups
data "netskope_npa_policy_groups_list" "all" {}
```

### Creating High-Availability Apps

Assign applications to multiple publishers for redundancy:

```hcl
publishers = [
  {
    publisher_id   = tostring(netskope_npa_publisher.primary.id)
    publisher_name = netskope_npa_publisher.primary.publisher_name
  },
  {
    publisher_id   = tostring(netskope_npa_publisher.secondary.id)
    publisher_name = netskope_npa_publisher.secondary.publisher_name
  }
]
```

### Rule Ordering

Control the order of policy rules:

```hcl
# Place at top
rule_order = {
  order = "top"
}

# Place after another rule
rule_order = {
  order   = "after"
  rule_id = tonumber(netskope_npa_rules.other_rule.id)
}

# Place at bottom
rule_order = {
  order = "bottom"
}
```
