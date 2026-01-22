# Tutorial: Managing Private App Inventory with Terraform

This tutorial shows how to manage your private application inventory using Terraform instead of the Netskope console. You'll learn to organize apps by environment, use variables for bulk management, and import existing apps into Terraform.

## Use Case

You have multiple private applications that need to be:
- Version controlled for audit trails
- Consistently configured across environments
- Managed as code for repeatability
- Bulk updated when publishers or policies change

## Prerequisites

- Netskope tenant with API access configured
- At least one publisher deployed and connected
- Terraform 1.0+ installed
- Basic familiarity with Terraform

## Run the Code

Ready-to-deploy Terraform configurations are available in [`code/private-app-inventory/`](../code/private-app-inventory/). You can deploy immediately and follow along with this tutorial for detailed explanations.

```bash
cd code/private-app-inventory
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform plan && terraform apply
```

## Project Structure

```
private-app-inventory/
├── main.tf              # Provider configuration
├── variables.tf         # Input variables
├── data.tf              # Data sources
├── apps-web.tf          # Web tier applications
├── apps-database.tf     # Database tier applications
├── apps-infrastructure.tf # Infrastructure applications
├── outputs.tf           # Output values
├── terraform.tfvars     # Variable values (don't commit)
└── apps.csv             # Optional: app definitions
```

## Step 1: Provider Configuration

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.3"
    }
  }
}

provider "netskope" {
  # Reads from NETSKOPE_SERVER_URL and NETSKOPE_API_KEY environment variables
}
```

## Step 2: Define Variables

Create `variables.tf`:

```hcl
variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "primary_publisher_name" {
  description = "Name of the primary publisher to use"
  type        = string
}

variable "secondary_publisher_name" {
  description = "Name of the secondary publisher for HA (optional)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Tags to apply to all applications"
  type        = list(string)
  default     = ["managed-by-terraform"]
}

# Web tier applications
variable "web_apps" {
  description = "Map of web applications to create"
  type = map(object({
    hostname          = string
    real_host         = string
    port              = optional(string, "443")
    clientless_access = optional(bool, true)
    tags              = optional(list(string), [])
  }))
  default = {}
}

# Database applications
variable "database_apps" {
  description = "Map of database applications to create"
  type = map(object({
    hostname  = string
    real_host = string
    port      = string
    protocol  = optional(string, "tcp")
    tags      = optional(list(string), [])
  }))
  default = {}
}

# Infrastructure applications (SSH, RDP, etc.)
variable "infra_apps" {
  description = "Map of infrastructure applications to create"
  type = map(object({
    hostname  = string
    real_host = string
    port      = string
    protocol  = optional(string, "tcp")
    app_type  = optional(string, "ssh")  # ssh, rdp, vnc
    tags      = optional(list(string), [])
  }))
  default = {}
}
```

## Step 3: Data Sources

Create `data.tf`:

```hcl
# =============================================================================
# Data Sources - Discover Existing Resources
# =============================================================================

# See: ../data-sources/npa_publishers_list.md
data "netskope_npa_publishers_list" "all" {}

# =============================================================================
# Local Values
# =============================================================================

locals {
  # Find publishers by name
  primary_publisher = [
    for pub in data.netskope_npa_publishers_list.all.data.publishers :
    pub if pub.publisher_name == var.primary_publisher_name
  ][0]

  secondary_publisher = var.secondary_publisher_name != "" ? [
    for pub in data.netskope_npa_publishers_list.all.data.publishers :
    pub if pub.publisher_name == var.secondary_publisher_name
  ][0] : null

  # Build publisher list for apps
  app_publishers = var.secondary_publisher_name != "" ? [
    {
      publisher_id   = tostring(local.primary_publisher.publisher_id)
      publisher_name = local.primary_publisher.publisher_name
    },
    {
      publisher_id   = tostring(local.secondary_publisher.publisher_id)
      publisher_name = local.secondary_publisher.publisher_name
    }
  ] : [
    {
      publisher_id   = tostring(local.primary_publisher.publisher_id)
      publisher_name = local.primary_publisher.publisher_name
    }
  ]

  # Common tags as objects
  common_tag_objects = [
    for tag in var.common_tags : { tag_name = tag }
  ]

  # Environment tag
  env_tag = [{ tag_name = var.environment }]
}
```

## Step 4: Web Tier Applications

Create `apps-web.tf`:

```hcl
# =============================================================================
# Web Tier Applications
# =============================================================================
# Browser-accessible applications (Jira, Confluence, internal portals, etc.)
#
# Note: For https apps, real_host must be a FQDN (not an IP address)
# See: ../resources/npa_private_app.md

resource "netskope_npa_private_app" "web" {
  for_each = var.web_apps

  private_app_name     = "${var.environment}-${each.key}"
  private_app_hostname = each.value.hostname
  private_app_protocol = "https"
  real_host            = each.value.real_host  # Must be FQDN for https apps

  clientless_access  = each.value.clientless_access
  is_user_portal_app = false  # Requires User Portal license
  use_publisher_dns  = true

  protocols = [
    {
      port     = each.value.port
      protocol = "tcp"
    }
  ]

  publishers = local.app_publishers

  tags = concat(
    local.common_tag_objects,
    local.env_tag,
    [{ tag_name = "web-tier" }],
    [for tag in each.value.tags : { tag_name = tag }]
  )
}
```

> **Common Mistakes - Web Apps**
>
> | Mistake | Error You'll See | Fix |
> |---------|------------------|-----|
> | IP address for `real_host` | `real_host must be FQDN for https protocol` | Use FQDN: `"server.internal.com"` not `"10.0.1.50"` |
> | Port as integer | Type conversion error | Use string: `port = "443"` not `port = 443` |
> | Missing protocol in URL | Connection fails | Ensure `private_app_protocol = "https"` |

## Step 5: Database Tier Applications

Create `apps-database.tf`:

```hcl
# =============================================================================
# Database Tier Applications
# =============================================================================
# Database connections (PostgreSQL, MySQL, MongoDB, etc.)

resource "netskope_npa_private_app" "database" {
  for_each = var.database_apps

  private_app_name     = "${var.environment}-${each.key}"
  private_app_hostname = each.value.hostname
  private_app_protocol = "tcp"
  real_host            = each.value.real_host

  clientless_access  = false
  is_user_portal_app = false
  use_publisher_dns  = true

  protocols = [
    {
      port     = each.value.port
      protocol = each.value.protocol
    }
  ]

  publishers = local.app_publishers

  tags = concat(
    local.common_tag_objects,
    local.env_tag,
    [{ tag_name = "database-tier" }],
    [for tag in each.value.tags : { tag_name = tag }]
  )
}
```

## Step 6: Infrastructure Applications

Create `apps-infrastructure.tf`:

```hcl
# =============================================================================
# Infrastructure Applications
# =============================================================================
# SSH, RDP, and other infrastructure access
#
# Note: real_host must be a single IP or FQDN (CIDR ranges not supported)

locals {
  # Map app_type to protocol settings
  infra_protocols = {
    ssh = "ssh"
    rdp = "rdp"
    vnc = "vnc"
  }
}

resource "netskope_npa_private_app" "infra" {
  for_each = var.infra_apps

  private_app_name     = "${var.environment}-${each.key}"
  private_app_hostname = each.value.hostname
  private_app_protocol = lookup(local.infra_protocols, each.value.app_type, "tcp")
  real_host            = each.value.real_host  # Single IP or FQDN only

  clientless_access  = true   # Required for SSH/RDP/VNC access
  is_user_portal_app = false
  use_publisher_dns  = true

  protocols = [
    {
      port     = each.value.port
      protocol = each.value.protocol
    }
  ]

  publishers = local.app_publishers

  tags = concat(
    local.common_tag_objects,
    local.env_tag,
    [{ tag_name = "infrastructure" }],
    [{ tag_name = each.value.app_type }],
    [for tag in each.value.tags : { tag_name = tag }]
  )
}
```

> **Common Mistakes - Infrastructure Apps**
>
> | Mistake | Error You'll See | Fix |
> |---------|------------------|-----|
> | CIDR range in `real_host` | `invalid host format` | Use single IP: `"10.0.1.50"` not `"10.0.1.0/24"` |
> | Missing `clientless_access = true` | SSH/RDP unreachable via browser | Add `clientless_access = true` for SSH, RDP, VNC |
> | Wrong `app_type` value | Protocol mismatch | Use `"ssh"`, `"rdp"`, or `"vnc"` |

## Step 7: Outputs

Create `outputs.tf`:

```hcl
# =============================================================================
# Outputs
# =============================================================================

output "web_apps" {
  description = "Created web tier applications"
  value = {
    for name, app in netskope_npa_private_app.web : name => {
      id       = app.private_app_id
      name     = app.private_app_name
      hostname = app.private_app_hostname
      url      = "https://${app.private_app_hostname}"
    }
  }
}

output "database_apps" {
  description = "Created database tier applications"
  value = {
    for name, app in netskope_npa_private_app.database : name => {
      id       = app.private_app_id
      name     = app.private_app_name
      hostname = app.private_app_hostname
      port     = app.protocols[0].port
    }
  }
}

output "infra_apps" {
  description = "Created infrastructure applications"
  value = {
    for name, app in netskope_npa_private_app.infra : name => {
      id       = app.private_app_id
      name     = app.private_app_name
      hostname = app.private_app_hostname
      port     = app.protocols[0].port
    }
  }
}

output "summary" {
  description = "Summary of created applications"
  value = {
    environment    = var.environment
    web_app_count  = length(netskope_npa_private_app.web)
    db_app_count   = length(netskope_npa_private_app.database)
    infra_app_count = length(netskope_npa_private_app.infra)
    total_apps     = (
      length(netskope_npa_private_app.web) +
      length(netskope_npa_private_app.database) +
      length(netskope_npa_private_app.infra)
    )
  }
}
```

## Step 8: Define Your Applications

Create `terraform.tfvars`:

```hcl
environment              = "production"
primary_publisher_name   = "us-west-dc1-primary"
secondary_publisher_name = "us-west-dc1-secondary"

common_tags = [
  "managed-by-terraform",
  "team-platform"
]

# Web Applications (real_host must be FQDN for https apps)
web_apps = {
  jira = {
    hostname  = "jira.internal.company.com"
    real_host = "jira-server.internal.company.com"
    port      = "443"
    tags      = ["devtools"]
  }

  confluence = {
    hostname  = "wiki.internal.company.com"
    real_host = "confluence-server.internal.company.com"
    port      = "443"
    tags      = ["devtools"]
  }

  grafana = {
    hostname  = "grafana.internal.company.com"
    real_host = "grafana-server.internal.company.com"
    port      = "3000"
    tags      = ["monitoring"]
  }

  jenkins = {
    hostname  = "jenkins.internal.company.com"
    real_host = "jenkins-server.internal.company.com"
    port      = "8080"
    tags      = ["devtools", "ci-cd"]
  }
}

# Database Applications
database_apps = {
  postgres-main = {
    hostname  = "postgres.internal.company.com"
    real_host = "10.0.3.10"
    port      = "5432"
    tags      = ["primary-db"]
  }

  postgres-replica = {
    hostname  = "postgres-ro.internal.company.com"
    real_host = "10.0.3.11"
    port      = "5432"
    tags      = ["replica-db"]
  }

  redis = {
    hostname  = "redis.internal.company.com"
    real_host = "10.0.3.20"
    port      = "6379"
    tags      = ["cache"]
  }

  mongodb = {
    hostname  = "mongo.internal.company.com"
    real_host = "10.0.3.30"
    port      = "27017"
    tags      = ["document-db"]
  }
}

# Infrastructure Applications (real_host must be single IP or FQDN, not CIDR)
infra_apps = {
  ssh-jumpbox = {
    hostname  = "jumpbox.internal.company.com"
    real_host = "10.0.0.10"
    port      = "22"
    app_type  = "ssh"
    tags      = ["admin-access"]
  }

  ssh-web-server = {
    hostname  = "web-ssh.internal.company.com"
    real_host = "10.0.1.50"
    port      = "22"
    app_type  = "ssh"
    tags      = ["web-tier"]
  }

  rdp-windows = {
    hostname  = "windows.internal.company.com"
    real_host = "10.0.4.50"
    port      = "3389"
    app_type  = "rdp"
    tags      = ["windows-admin"]
  }
}
```

## Step 9: Deploy

```bash
# Initialize Terraform
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
# Preview changes
terraform plan
```

Expected output:
```
data.netskope_npa_publishers_list.all: Reading...
data.netskope_npa_publishers_list.all: Read complete after 1s

Terraform will perform the following actions:

  # netskope_npa_private_app.web["confluence"] will be created
  # netskope_npa_private_app.web["grafana"] will be created
  # netskope_npa_private_app.web["jenkins"] will be created
  # netskope_npa_private_app.web["jira"] will be created
  # netskope_npa_private_app.database["mongodb"] will be created
  # netskope_npa_private_app.database["postgres-main"] will be created
  ...

Plan: 11 to add, 0 to change, 0 to destroy.
```

```bash
# Apply configuration
terraform apply
```

Expected output after confirmation:
```
netskope_npa_private_app.web["jira"]: Creating...
netskope_npa_private_app.web["confluence"]: Creating...
...
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

summary = {
  "db_app_count"    = 4
  "environment"     = "production"
  "infra_app_count" = 3
  "total_apps"      = 11
  "web_app_count"   = 4
}
```

## Importing Existing Applications

If you have existing applications in Netskope that you want to manage with Terraform:

### 1. Discover Existing Apps

```hcl
# discovery.tf (temporary file)
# See: ../data-sources/npa_private_apps_list.md
data "netskope_npa_private_apps_list" "existing" {}

output "existing_apps" {
  value = [
    for app in data.netskope_npa_private_apps_list.existing.private_apps : {
      id       = app.private_app_id
      name     = app.private_app_name
      hostname = app.private_app_hostname
    }
  ]
}
```

Run `terraform apply` to see the list.

### 2. Write Matching Configuration

For each app you want to import, write a resource that matches its current configuration:

```hcl
resource "netskope_npa_private_app" "existing_jira" {
  private_app_name     = "existing-jira"  # Must match exactly
  private_app_hostname = "jira.internal.company.com"
  # ... match other settings
}
```

### 3. Import the Resource

```bash
terraform import 'netskope_npa_private_app.existing_jira' <app_id>
```

### 4. Verify with Plan

```bash
terraform plan
```

If the plan shows no changes, the import was successful.

## Managing Multiple Environments

### Option 1: Workspaces

```bash
# Create workspaces
terraform workspace new production
terraform workspace new staging
terraform workspace new development

# Switch workspace
terraform workspace select staging

# Apply with environment-specific vars
terraform apply -var-file=environments/staging.tfvars
```

### Option 2: Separate Directories

```
environments/
├── production/
│   ├── main.tf -> ../../modules/app-inventory
│   ├── terraform.tfvars
│   └── backend.tf
├── staging/
│   └── ...
└── development/
    └── ...
```

## Adding a New Application

To add a new application, simply add it to your `terraform.tfvars`:

```hcl
web_apps = {
  # ... existing apps ...

  # New app
  new-portal = {
    hostname  = "portal.internal.company.com"
    real_host = "portal-server.internal.company.com"
    port      = "443"
    tags      = ["new-project"]
  }
}
```

Then run:

```bash
terraform plan   # Review the addition
terraform apply  # Create the app
```

## Removing an Application

To remove an application, delete it from `terraform.tfvars` and run:

```bash
terraform plan   # Shows app will be destroyed
terraform apply  # Removes the app
```

## Best Practices

1. **Use consistent naming**: `{environment}-{app-name}` pattern
2. **Tag everything**: Makes filtering and reporting easier
3. **Use HA publishers**: Assign multiple publishers for redundancy
4. **Version control**: Commit all `.tf` files, never commit `.tfvars`
5. **Review plans**: Always review `terraform plan` before applying
6. **Use modules**: Extract common patterns into reusable modules

## Next Steps

- [Policy as Code Tutorial](./policy-as-code.md) - Create access rules for your applications
- [Publisher AWS Tutorial](./publisher-aws.md) - Deploy publishers in AWS
- [Best Practices Guide](../guides/best-practices.md) - More organizational patterns
