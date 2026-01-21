# Best Practices Guide

This guide covers recommended patterns and practices for managing Netskope NPA resources with Terraform.

## Project Structure

### Single Environment

For small deployments or single environments:

```
netskope-npa/
├── main.tf              # Provider and main resources
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── data.tf              # Data sources
├── terraform.tfvars     # Variable values (don't commit)
└── .gitignore
```

### Multiple Environments

For production deployments with multiple environments:

```
netskope-npa/
├── modules/
│   ├── private-app/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── publisher/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── policy/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── production/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── development/
│       ├── main.tf
│       ├── terraform.tfvars
│       └── backend.tf
└── .gitignore
```

### Workspace-Based Structure

Using Terraform workspaces for environment separation:

```
netskope-npa/
├── main.tf
├── variables.tf
├── outputs.tf
├── environments/
│   ├── production.tfvars
│   ├── staging.tfvars
│   └── development.tfvars
└── backend.tf
```

Usage:
```bash
terraform workspace select production
terraform apply -var-file=environments/production.tfvars
```

---

## Naming Conventions

### Terraform Resource Names

Use snake_case for Terraform resource names:

```hcl
# Good
resource "netskope_npa_private_app" "internal_web_portal" { }
resource "netskope_npa_publisher" "us_west_primary" { }

# Avoid
resource "netskope_npa_private_app" "InternalWebPortal" { }
resource "netskope_npa_private_app" "internal-web-portal" { }
```

### API Object Names

Use kebab-case or descriptive names for API-side objects:

```hcl
resource "netskope_npa_private_app" "jira" {
  private_app_name = "prod-jira-internal"  # kebab-case
  # ...
}

resource "netskope_npa_publisher" "datacenter_primary" {
  publisher_name = "us-west-dc1-primary"  # location-purpose pattern
  # ...
}
```

### Naming Pattern Examples

| Resource Type | Terraform Name | API Name |
|---------------|----------------|----------|
| Private App | `internal_jira` | `prod-jira-internal` |
| Publisher | `us_west_primary` | `us-west-dc1-primary` |
| Policy Group | `production_access` | `Production Access` |
| NPA Rule | `allow_web_access` | `Allow-Web-Access` |
| Upgrade Profile | `weekly_sunday` | `weekly-sun-2am` |

---

## Using Data Sources Effectively

### Always Discover, Never Hardcode

```hcl
# Good: Dynamic reference
data "netskope_npa_publishers_list" "all" {}

locals {
  publisher = data.netskope_npa_publishers_list.all.data.publishers[0]
}

resource "netskope_npa_private_app" "example" {
  publishers = [
    {
      publisher_id   = tostring(local.publisher.publisher_id)
      publisher_name = local.publisher.publisher_name
    }
  ]
}

# Avoid: Hardcoded ID
resource "netskope_npa_private_app" "example" {
  publishers = [
    {
      publisher_id   = "4"  # Will break if ID changes
      publisher_name = "my-publisher"
    }
  ]
}
```

### Filter by Name for Reliability

```hcl
data "netskope_npa_publishers_list" "all" {}

locals {
  # Filter by name - more reliable than index
  target_publisher = [
    for pub in data.netskope_npa_publishers_list.all.data.publishers :
    pub if pub.publisher_name == var.publisher_name
  ][0]
}
```

### Centralize Data Sources

Create a dedicated file for data sources used across multiple resources:

```hcl
# data.tf
data "netskope_npa_publishers_list" "all" {}
data "netskope_npa_private_apps_list" "all" {}
data "netskope_npa_policy_groups_list" "all" {}

locals {
  # Commonly used values
  publishers   = data.netskope_npa_publishers_list.all.data.publishers
  private_apps = data.netskope_npa_private_apps_list.all.private_apps
  policy_groups = data.netskope_npa_policy_groups_list.all.data

  # Specific selections
  primary_publisher = [
    for pub in local.publishers :
    pub if pub.publisher_name == var.primary_publisher_name
  ][0]

  default_policy_group = [
    for pg in local.policy_groups :
    pg if pg.group_name == "Default"
  ][0]
}
```

---

## Security Best Practices

### Credential Management

1. **Never commit credentials:**
   ```gitignore
   # .gitignore
   *.tfvars
   *.tfvars.json
   .terraform/
   terraform.tfstate
   terraform.tfstate.backup
   ```

2. **Use environment variables:**
   ```bash
   export NETSKOPE_SERVER_URL="https://tenant.goskope.com/api/v2"
   export NETSKOPE_API_KEY="your-api-key"
   ```

3. **For CI/CD, use secrets management:**
   - GitHub Actions: Repository secrets
   - GitLab CI: CI/CD variables (masked)
   - Terraform Cloud: Workspace variables (sensitive)

### State File Security

1. **Use remote state with encryption:**
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "my-terraform-state"
       key            = "netskope/terraform.tfstate"
       region         = "us-west-2"
       encrypt        = true
       dynamodb_table = "terraform-locks"
     }
   }
   ```

2. **Restrict state access:**
   - Use IAM policies to limit who can read state
   - Enable versioning for state recovery
   - Enable access logging for audit trails

### Least Privilege API Keys

Create separate API keys for different purposes:

| Key Purpose | Required Endpoints |
|-------------|-------------------|
| Read-only monitoring | GET endpoints only |
| App management | `/steering/apps/private` |
| Full NPA management | All NPA endpoints |

---

## Resource Organization

### Use Tags Consistently

```hcl
locals {
  common_tags = [
    { tag_name = "managed-by-terraform" },
    { tag_name = var.environment },
    { tag_name = var.team }
  ]
}

resource "netskope_npa_private_app" "example" {
  private_app_name = "my-app"
  tags             = local.common_tags
  # ...
}
```

### Group Related Resources

```hcl
# =============================================================================
# Web Tier Applications
# =============================================================================

resource "netskope_npa_private_app" "web_portal" {
  private_app_name = "${var.environment}-web-portal"
  tags = concat(local.common_tags, [{ tag_name = "web-tier" }])
  # ...
}

resource "netskope_npa_private_app" "web_api" {
  private_app_name = "${var.environment}-web-api"
  tags = concat(local.common_tags, [{ tag_name = "web-tier" }])
  # ...
}

# =============================================================================
# Database Tier Applications
# =============================================================================

resource "netskope_npa_private_app" "postgres" {
  private_app_name = "${var.environment}-postgres"
  tags = concat(local.common_tags, [{ tag_name = "database-tier" }])
  # ...
}
```

---

## Module Patterns

### Reusable Private App Module

```hcl
# modules/private-app/variables.tf
variable "app_name" {
  type = string
}

variable "hostname" {
  type = string
}

variable "real_host" {
  type = string
}

variable "port" {
  type    = string
  default = "443"
}

variable "protocol" {
  type    = string
  default = "tcp"
}

variable "publisher_id" {
  type = string
}

variable "publisher_name" {
  type = string
}

variable "clientless_access" {
  type    = bool
  default = false
}

variable "tags" {
  type    = list(object({ tag_name = string }))
  default = []
}

# modules/private-app/main.tf
resource "netskope_npa_private_app" "this" {
  private_app_name     = var.app_name
  private_app_hostname = var.hostname
  private_app_protocol = "https"
  real_host            = var.real_host

  clientless_access  = var.clientless_access
  is_user_portal_app = var.clientless_access
  use_publisher_dns  = true

  protocols = [
    {
      port     = var.port
      protocol = var.protocol
    }
  ]

  publishers = [
    {
      publisher_id   = var.publisher_id
      publisher_name = var.publisher_name
    }
  ]

  tags = var.tags
}

# modules/private-app/outputs.tf
output "app_id" {
  value = netskope_npa_private_app.this.private_app_id
}

output "app_name" {
  value = netskope_npa_private_app.this.private_app_name
}
```

### Using the Module

```hcl
module "jira" {
  source = "./modules/private-app"

  app_name          = "prod-jira"
  hostname          = "jira.internal.company.com"
  real_host         = "10.0.1.100"
  port              = "443"
  publisher_id      = tostring(local.primary_publisher.publisher_id)
  publisher_name    = local.primary_publisher.publisher_name
  clientless_access = true

  tags = [
    { tag_name = "production" },
    { tag_name = "web" }
  ]
}

module "gitlab" {
  source = "./modules/private-app"

  app_name          = "prod-gitlab"
  hostname          = "gitlab.internal.company.com"
  real_host         = "10.0.1.101"
  port              = "443"
  publisher_id      = tostring(local.primary_publisher.publisher_id)
  publisher_name    = local.primary_publisher.publisher_name
  clientless_access = true

  tags = [
    { tag_name = "production" },
    { tag_name = "devtools" }
  ]
}
```

---

## Import Strategies

### When to Import vs Recreate

**Import when:**
- Resource has dependencies (other resources reference it)
- Resource has significant configuration
- Downtime is not acceptable

**Recreate when:**
- Resource is simple and standalone
- You want a clean state
- Resource can be briefly unavailable

### Import Workflow

1. **Identify the resource ID** using data sources
2. **Write the Terraform configuration** matching the existing resource
3. **Import the resource:**
   ```bash
   terraform import netskope_npa_private_app.existing_app <app_id>
   ```
4. **Run plan to verify:**
   ```bash
   terraform plan
   ```
5. **Adjust configuration** if plan shows changes

### Import Examples

```bash
# Private App
terraform import netskope_npa_private_app.my_app 123

# Publisher
terraform import netskope_npa_publisher.my_publisher 456

# Policy Group
terraform import netskope_npa_policy_groups.my_group 789

# NPA Rule
terraform import netskope_npa_rules.my_rule 101
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Terraform

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  NETSKOPE_SERVER_URL: ${{ secrets.NETSKOPE_SERVER_URL }}
  NETSKOPE_API_KEY: ${{ secrets.NETSKOPE_API_KEY }}

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0

      - name: Terraform Init
        run: terraform init

      - name: Terraform Format Check
        run: terraform fmt -check

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=plan.tfplan

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: terraform-plan
          path: plan.tfplan

  apply:
    needs: plan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: terraform-plan

      - name: Terraform Init
        run: terraform init

      - name: Terraform Apply
        run: terraform apply plan.tfplan
```

### Plan Review Process

1. **PR creates plan** - Terraform plan runs on every PR
2. **Review plan output** - Team reviews proposed changes
3. **Merge to main** - Approved changes merged
4. **Auto-apply** - Changes applied automatically (or manually with approval)

---

## Performance Tips

### Limit Data Source Scope

```hcl
# If you only need specific apps, use query parameter
data "netskope_npa_private_apps_list" "filtered" {
  query = "app_name eq 'prod-*'"
  limit = 100
}
```

### Use Targeted Operations

```bash
# Apply only specific resources
terraform apply -target=netskope_npa_private_app.critical_app

# Plan specific resources
terraform plan -target=module.web_apps
```

### Parallelize Independent Resources

Terraform automatically parallelizes resources without dependencies. Structure your code to minimize artificial dependencies.

---

## Version Control

### Commit Messages

Use clear, descriptive commit messages:

```
feat(apps): add production web portal application

- Configure HTTPS access on port 443
- Assign to us-west-dc1 publisher
- Enable browser access for end users

Refs: TICKET-123
```

### Branch Strategy

```
main                 # Production state
├── develop          # Integration branch
├── feature/add-app  # Feature branches
└── hotfix/fix-rule  # Urgent fixes
```

### Code Review Checklist

- [ ] `terraform fmt` passes
- [ ] `terraform validate` passes
- [ ] Plan output reviewed
- [ ] No hardcoded IDs or credentials
- [ ] Appropriate tags applied
- [ ] Documentation updated if needed
