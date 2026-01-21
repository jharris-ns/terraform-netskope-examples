# Tutorial: Policy as Code with NPA Rules

This tutorial shows how to manage Netskope NPA access policies using Terraform. You'll learn to create policy groups, define access rules, manage rule ordering, and implement role-based access patterns.

## NPA Policy Hierarchy

```
┌─────────────────────────────────────────────────┐
│               Policy Groups                      │
│  ┌───────────────────────────────────────────┐  │
│  │  Default Group (ID: 1)                    │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │  Rule 1: Deny-Blocked-Users         │  │  │
│  │  │  Rule 2: Allow-Admin-SSH            │  │  │
│  │  │  Rule 3: Allow-Dev-Web-Apps         │  │  │
│  │  │  Rule 4: Allow-All-Browser-Apps     │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────┐  │
│  │  Production Group                         │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │  Rule 1: Allow-Prod-DB-Access       │  │  │
│  │  │  Rule 2: Allow-Prod-Web-Access      │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

Rules are evaluated top-to-bottom. First matching rule wins.

## Prerequisites

- Netskope tenant with API access
- Private applications created (see [Private App Inventory Tutorial](./private-app-inventory.md))
- User groups configured in your IdP
- Terraform 1.0+ installed

## Project Structure

```
npa-policies/
├── main.tf              # Provider configuration
├── variables.tf         # Input variables
├── data.tf              # Data sources
├── policy-groups.tf     # Policy group definitions
├── rules-deny.tf        # Deny rules (processed first)
├── rules-admin.tf       # Admin access rules
├── rules-teams.tf       # Team-based access rules
├── rules-general.tf     # General access rules
├── outputs.tf           # Output values
└── terraform.tfvars     # Variable values
```

## Step 1: Provider Configuration

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskope/netskope"
      version = ">= 0.3.0"
    }
  }
}

provider "netskope" {}
```

## Step 2: Variables

Create `variables.tf`:

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# =============================================================================
# User Groups (from your IdP)
# =============================================================================

variable "admin_groups" {
  description = "Groups with admin/infrastructure access"
  type        = list(string)
  default     = ["IT-Administrators", "SRE-Team"]
}

variable "developer_groups" {
  description = "Groups with developer access"
  type        = list(string)
  default     = ["Developers", "Engineering"]
}

variable "dba_groups" {
  description = "Groups with database access"
  type        = list(string)
  default     = ["Database-Admins", "SRE-Team"]
}

variable "blocked_groups" {
  description = "Groups explicitly denied access"
  type        = list(string)
  default     = ["Contractors-Terminated", "Security-Quarantine"]
}

# =============================================================================
# Application Tags (for rule targeting)
# =============================================================================

variable "web_app_tags" {
  description = "Tags identifying web applications"
  type        = list(string)
  default     = ["web-tier"]
}

variable "database_app_tags" {
  description = "Tags identifying database applications"
  type        = list(string)
  default     = ["database-tier"]
}

variable "infrastructure_app_tags" {
  description = "Tags identifying infrastructure applications"
  type        = list(string)
  default     = ["infrastructure"]
}
```

## Step 3: Data Sources

Create `data.tf`:

```hcl
# =============================================================================
# Discover Existing Resources
# =============================================================================

# Policy groups - see: ../data-sources/npa_policy_groups_list.md
data "netskope_npa_policy_groups_list" "all" {}

# Private apps (to reference by name in rules) - see: ../data-sources/npa_private_apps_list.md
data "netskope_npa_private_apps_list" "all" {}

# Existing rules (for ordering) - see: ../data-sources/npa_rules_list.md
data "netskope_npa_rules_list" "all" {}

# =============================================================================
# Local Values
# =============================================================================

locals {
  # Find the default policy group
  default_group = [
    for pg in data.netskope_npa_policy_groups_list.all.data :
    pg if pg.group_name == "Default"
  ][0]

  # Group apps by tags for easy reference
  web_apps = [
    for app in data.netskope_npa_private_apps_list.all.private_apps :
    app.private_app_name
    if length([
      for tag in coalesce(app.tags, []) :
      tag if contains(var.web_app_tags, tag.tag_name)
    ]) > 0
  ]

  database_apps = [
    for app in data.netskope_npa_private_apps_list.all.private_apps :
    app.private_app_name
    if length([
      for tag in coalesce(app.tags, []) :
      tag if contains(var.database_app_tags, tag.tag_name)
    ]) > 0
  ]

  infrastructure_apps = [
    for app in data.netskope_npa_private_apps_list.all.private_apps :
    app.private_app_name
    if length([
      for tag in coalesce(app.tags, []) :
      tag if contains(var.infrastructure_app_tags, tag.tag_name)
    ]) > 0
  ]

  # All app names (for general rules)
  all_app_names = [
    for app in data.netskope_npa_private_apps_list.all.private_apps :
    app.private_app_name
  ]
}
```

## Step 4: Deny Rules (First Priority)

Create `rules-deny.tf`:

```hcl
# =============================================================================
# Deny Rules
# =============================================================================
# These rules are placed at the top and evaluated first.
# Deny rules should explicitly block access for specific conditions.

# Block terminated/quarantined users from all access
# See: ../resources/npa_rules.md
resource "netskope_npa_rules" "deny_blocked_users" {
  rule_name   = "${var.environment}-deny-blocked-users"
  description = "Block access for terminated and quarantined users"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    # Deny action
    match_criteria_action = {
      action_name = "block"
    }

    # Apply to all apps
    private_apps = [for name in local.all_app_names : "[${name}]"]

    # Target blocked groups
    user_groups = var.blocked_groups

    # All access methods
    access_method = ["Client", "Clientless"]

    # User type
    user_type = "user"
  }

  # Place at the very top
  rule_order = {
    order = "top"
  }
}
```

> **Common Mistakes - Policy Rules**
>
> | Mistake | What Happens | Fix |
> |---------|--------------|-----|
> | `enabled = true` | Type error | Use string: `enabled = "1"` |
> | `enabled = 1` | Type error | Use string: `enabled = "1"` |
> | Missing `depends_on` | Rules created in wrong order | Add `depends_on = [netskope_npa_rules.previous_rule]` |
> | Deny rule at bottom | Deny never matches (allow rule matches first) | Use `rule_order = { order = "top" }` for deny rules |
> | Using `.id` instead of correct attribute | Attribute not found | Check resource documentation for correct attribute name |

## Step 5: Admin Access Rules

Create `rules-admin.tf`:

```hcl
# =============================================================================
# Admin/Infrastructure Access Rules
# =============================================================================
# These rules grant privileged access to admin groups.

# Admin SSH access to infrastructure
resource "netskope_npa_rules" "admin_ssh_access" {
  count = length(local.infrastructure_apps) > 0 ? 1 : 0

  rule_name   = "${var.environment}-admin-ssh-access"
  description = "Allow admin groups SSH access to infrastructure"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    # Infrastructure apps only
    private_apps = [for name in local.infrastructure_apps : "[${name}]"]

    # Admin groups
    user_groups = var.admin_groups

    # Client access only (SSH requires client)
    access_method = ["Client"]

    user_type = "user"
  }

  rule_order = {
    order   = "after"
    rule_id = tonumber(netskope_npa_rules.deny_blocked_users.id)
  }

  depends_on = [netskope_npa_rules.deny_blocked_users]
}

# Admin database access
resource "netskope_npa_rules" "admin_database_access" {
  count = length(local.database_apps) > 0 ? 1 : 0

  rule_name   = "${var.environment}-admin-database-access"
  description = "Allow admin and DBA groups access to databases"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps = [for name in local.database_apps : "[${name}]"]

    # Admin and DBA groups
    user_groups = concat(var.admin_groups, var.dba_groups)

    access_method = ["Client"]

    user_type = "user"
  }

  rule_order = {
    order   = "after"
    rule_id = length(local.infrastructure_apps) > 0 ? tonumber(netskope_npa_rules.admin_ssh_access[0].id) : tonumber(netskope_npa_rules.deny_blocked_users.id)
  }

  depends_on = [
    netskope_npa_rules.deny_blocked_users,
    netskope_npa_rules.admin_ssh_access
  ]
}
```

## Step 6: Team-Based Access Rules

Create `rules-teams.tf`:

```hcl
# =============================================================================
# Team-Based Access Rules
# =============================================================================
# These rules grant access based on team membership.

# Developer access to web applications
resource "netskope_npa_rules" "developer_web_access" {
  count = length(local.web_apps) > 0 ? 1 : 0

  rule_name   = "${var.environment}-developer-web-access"
  description = "Allow developers browser access to web applications"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps = [for name in local.web_apps : "[${name}]"]

    user_groups = var.developer_groups

    # Browser and client access
    access_method = ["Client", "Clientless"]

    user_type = "user"
  }

  rule_order = {
    order = "bottom"
  }
}

# DBA read-only database access (separate from admin full access)
resource "netskope_npa_rules" "dba_readonly_access" {
  count = length(local.database_apps) > 0 ? 1 : 0

  rule_name   = "${var.environment}-dba-database-access"
  description = "Allow DBA team access to databases"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps = [for name in local.database_apps : "[${name}]"]

    user_groups = var.dba_groups

    access_method = ["Client"]

    user_type = "user"
  }

  rule_order = {
    order   = "after"
    rule_id = length(local.web_apps) > 0 ? tonumber(netskope_npa_rules.developer_web_access[0].id) : tonumber(netskope_npa_rules.deny_blocked_users.id)
  }

  depends_on = [netskope_npa_rules.developer_web_access]
}
```

## Step 7: General Access Rules

Create `rules-general.tf`:

```hcl
# =============================================================================
# General Access Rules
# =============================================================================
# Broader access rules for general user populations.
# These are typically placed lower in the rule order.

# All users browser access to portal applications
resource "netskope_npa_rules" "general_browser_access" {
  rule_name   = "${var.environment}-general-browser-access"
  description = "Allow all authenticated users browser access to portal apps"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    # Only apps tagged as user-portal
    private_apps = [
      for app in data.netskope_npa_private_apps_list.all.private_apps :
      "[${app.private_app_name}]"
      if app.is_user_portal_app == true
    ]

    # All users
    user_type = "user"

    # Browser only
    access_method = ["Clientless"]
  }

  rule_order = {
    order = "bottom"
  }
}

# Catch-all deny rule (optional - for explicit deny-by-default)
resource "netskope_npa_rules" "deny_all_other" {
  rule_name   = "${var.environment}-deny-all-other"
  description = "Deny all access not explicitly allowed above"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "block"
    }

    # All apps
    private_apps = [for name in local.all_app_names : "[${name}]"]

    user_type = "user"

    access_method = ["Client", "Clientless"]
  }

  rule_order = {
    order = "bottom"
  }

  # Ensure this is truly last
  depends_on = [
    netskope_npa_rules.general_browser_access
  ]
}
```

## Step 8: Outputs

Create `outputs.tf`:

```hcl
output "rule_order" {
  description = "Rules in order of evaluation"
  value = [
    {
      order = 1
      name  = netskope_npa_rules.deny_blocked_users.rule_name
      id    = netskope_npa_rules.deny_blocked_users.id
    },
    length(local.infrastructure_apps) > 0 ? {
      order = 2
      name  = netskope_npa_rules.admin_ssh_access[0].rule_name
      id    = netskope_npa_rules.admin_ssh_access[0].id
    } : null,
    length(local.database_apps) > 0 ? {
      order = 3
      name  = netskope_npa_rules.admin_database_access[0].rule_name
      id    = netskope_npa_rules.admin_database_access[0].id
    } : null,
    length(local.web_apps) > 0 ? {
      order = 4
      name  = netskope_npa_rules.developer_web_access[0].rule_name
      id    = netskope_npa_rules.developer_web_access[0].id
    } : null,
    {
      order = 5
      name  = netskope_npa_rules.general_browser_access.rule_name
      id    = netskope_npa_rules.general_browser_access.id
    },
    {
      order = 6
      name  = netskope_npa_rules.deny_all_other.rule_name
      id    = netskope_npa_rules.deny_all_other.id
    }
  ]
}

output "apps_by_category" {
  description = "Applications grouped by category"
  value = {
    web_apps           = local.web_apps
    database_apps      = local.database_apps
    infrastructure_apps = local.infrastructure_apps
  }
}
```

## Step 9: Deploy

Create `terraform.tfvars`:

```hcl
environment = "production"

# Map these to your actual IdP groups
admin_groups = [
  "IT-Administrators",
  "SRE-Team"
]

developer_groups = [
  "Engineering",
  "Developers"
]

dba_groups = [
  "Database-Admins"
]

blocked_groups = [
  "Terminated-Users",
  "Security-Quarantine"
]

# Tags used in your private app definitions
web_app_tags = ["web-tier"]
database_app_tags = ["database-tier"]
infrastructure_app_tags = ["infrastructure", "ssh"]
```

Deploy:

```bash
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding netskope/netskope versions matching ">= 0.3.0"...
- Installing netskope/netskope v0.3.5...

Terraform has been successfully initialized!
```

```bash
terraform plan
```

Expected output:
```
data.netskope_npa_policy_groups_list.all: Reading...
data.netskope_npa_private_apps_list.all: Reading...
data.netskope_npa_rules_list.all: Reading...
...

Terraform will perform the following actions:

  # netskope_npa_rules.deny_blocked_users will be created
  # netskope_npa_rules.admin_ssh_access[0] will be created
  # netskope_npa_rules.admin_database_access[0] will be created
  # netskope_npa_rules.developer_web_access[0] will be created
  # netskope_npa_rules.general_browser_access will be created
  # netskope_npa_rules.deny_all_other will be created

Plan: 6 to add, 0 to change, 0 to destroy.
```

```bash
terraform apply
```

Expected output after confirmation:
```
netskope_npa_rules.deny_blocked_users: Creating...
netskope_npa_rules.deny_blocked_users: Creation complete after 2s [id=1001]
netskope_npa_rules.admin_ssh_access[0]: Creating...
netskope_npa_rules.admin_ssh_access[0]: Creation complete after 1s [id=1002]
...
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

rule_order = [
  { order = 1, name = "production-deny-blocked-users", id = "1001" },
  { order = 2, name = "production-admin-ssh-access", id = "1002" },
  ...
]
```

## Rule Ordering Best Practices

### Recommended Order

1. **Deny rules first** - Explicit blocks (terminated users, security holds)
2. **Admin/privileged access** - IT, SRE, DBA access
3. **Team-based access** - Developer, support team access
4. **General access** - All authenticated users
5. **Catch-all deny** - Explicit deny-by-default (optional)

### Using depends_on

Always use `depends_on` to ensure proper rule ordering:

```hcl
resource "netskope_npa_rules" "rule_2" {
  # ...

  rule_order = {
    order   = "after"
    rule_id = tonumber(netskope_npa_rules.rule_1.id)
  }

  depends_on = [netskope_npa_rules.rule_1]
}
```

## Modifying Rules

### Adding a New Rule

1. Add the rule resource to the appropriate file
2. Set `rule_order` to position it correctly
3. Update `depends_on` for rules that should come after it
4. Run `terraform plan` to verify ordering
5. Run `terraform apply`

### Reordering Rules

1. Update `rule_order` blocks for affected rules
2. Ensure `depends_on` chains are correct
3. Apply changes

### Disabling a Rule

Set `enabled = "0"` instead of deleting:

```hcl
resource "netskope_npa_rules" "temporary_access" {
  enabled = "0"  # Disabled but preserved
  # ...
}
```

## Testing Policies

### Verify Rule Order

After applying, check the rule order in the Netskope console or via data source:

```hcl
data "netskope_npa_rules_list" "verify" {
  depends_on = [
    netskope_npa_rules.deny_all_other
  ]
}

output "current_rule_order" {
  value = [
    for rule in data.netskope_npa_rules_list.verify.data : {
      name    = rule.rule_name
      enabled = rule.enabled
    }
  ]
}
```

### Test Access

1. Log in as a user in different groups
2. Verify access matches expected behavior
3. Check NPA logs for rule matches

## Cleanup

```bash
terraform destroy
```

**Warning:** Destroying rules may disrupt user access. Consider disabling rules first, then destroying after verification.

## Next Steps

- [Private App Inventory Tutorial](./private-app-inventory.md) - Manage applications
- [Best Practices Guide](../guides/best-practices.md) - More organizational patterns
- [Troubleshooting Guide](../guides/troubleshooting.md) - Debug policy issues
