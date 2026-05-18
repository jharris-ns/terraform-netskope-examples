# Private App Inventory

Manage multiple private applications at scale using variables and loops. Organizes apps by tier (web, database, infrastructure) with consistent tagging and high-availability publisher assignment.

**Difficulty:** Intermediate

## Quick Start

```bash
cd examples/private-app-inventory
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your apps and publisher names

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init && terraform plan && terraform apply
```

## What This Creates

- Web tier applications (HTTPS, browser-accessible)
- Database tier applications (PostgreSQL, Redis, MongoDB)
- Infrastructure applications (SSH, RDP)
- Consistent tagging across all applications
- High-availability with multiple publishers (optional)

## Use Case

You have multiple private applications that need to be:
- Version controlled for audit trails
- Consistently configured across environments
- Managed as code for repeatability
- Bulk updated when publishers or policies change

## Prerequisites

- At least one registered NPA publisher
- Publisher names known for configuration

## File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration |
| `variables.tf` | Input variable definitions |
| `data.tf` | Publisher lookup and common locals |
| `apps-web.tf` | Web tier application resources |
| `apps-database.tf` | Database tier application resources |
| `apps-infrastructure.tf` | Infrastructure application resources |
| `outputs.tf` | Output values |
| `terraform.tfvars.example` | Example variable values |

## How It Works

### Publisher Lookup by Name

Publishers are looked up dynamically by name. See `data.tf`:

```hcl
# Pattern: Selection by name from data source
# See: getting-started/terraform-basics.md for pattern details
primary_publisher = [
  for pub in data.netskope_npa_publishers_list.all.data.publishers :
  pub if pub.publisher_name == var.primary_publisher_name
][0]
```

### Building Publisher Lists

Private apps require publishers as a list of objects:

```hcl
# Pattern: Building object lists
# See: getting-started/terraform-basics.md for pattern details
app_publishers = [
  {
    publisher_id   = tostring(local.primary_publisher.publisher_id)
    publisher_name = local.primary_publisher.publisher_name
  }
]
```

Note: `publisher_id` must be a string - use `tostring()` to convert.

### Tag Formatting

Tags must be formatted as objects:

```hcl
# Pattern: Convert strings to tag objects
# See: getting-started/terraform-basics.md for pattern details
common_tag_objects = [
  for tag in var.common_tags : { tag_name = tag }
]
```

### Dynamic Resource Creation with for_each

Apps are created dynamically from variable maps:

```hcl
# Pattern: for_each with maps
# See: getting-started/terraform-basics.md for pattern details
resource "netskope_npa_private_app" "web" {
  for_each = var.web_apps

  private_app_name     = "${var.environment}-${each.key}"
  private_app_hostname = each.value.hostname
  # ...
}
```

## Common Mistakes

| Mistake | Error You'll See | Fix |
|---------|------------------|-----|
| IP address for `real_host` (HTTPS apps) | `real_host must be FQDN for https protocol` | Use FQDN: `"server.internal.com"` |
| Port as integer | Type conversion error | Use string: `port = "443"` |
| CIDR range in `real_host` | `invalid host format` | Use single IP or FQDN |
| Missing `clientless_access = true` for SSH/RDP | Protocol unreachable | Add `clientless_access = true` |

## Example terraform.tfvars

```hcl
environment              = "production"
primary_publisher_name   = "us-west-dc1-primary"
secondary_publisher_name = "us-west-dc1-secondary"  # Optional for HA

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
}

# Database Applications
database_apps = {
  postgres-main = {
    hostname  = "postgres.internal.company.com"
    real_host = "10.0.3.10"
    port      = "5432"
    tags      = ["primary-db"]
  }

  redis = {
    hostname  = "redis.internal.company.com"
    real_host = "10.0.3.20"
    port      = "6379"
    tags      = ["cache"]
  }
}

# Infrastructure Applications (real_host must be single IP or FQDN)
infra_apps = {
  ssh-jumpbox = {
    hostname  = "jumpbox.internal.company.com"
    real_host = "10.0.0.10"
    port      = "22"
    app_type  = "ssh"
    tags      = ["admin-access"]
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

## Adding Applications

Add new apps by editing `terraform.tfvars`:

```hcl
web_apps = {
  # existing apps...

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

## Removing Applications

Delete the app from `terraform.tfvars` and run:

```bash
terraform plan   # Shows app will be destroyed
terraform apply  # Removes the app
```

## Importing Existing Applications

To manage existing apps with Terraform:

1. **Discover existing apps:**
   ```hcl
   data "netskope_npa_private_apps_list" "existing" {}

   output "existing_apps" {
     value = [
       for app in data.netskope_npa_private_apps_list.existing.private_apps : {
         id   = app.private_app_id
         name = app.private_app_name
       }
     ]
   }
   ```

2. **Write matching configuration** for each app

3. **Import:**
   ```bash
   terraform import 'netskope_npa_private_app.web["jira"]' <app_id>
   ```

4. **Verify:**
   ```bash
   terraform plan  # Should show no changes
   ```

## Cleanup

```bash
terraform destroy
```

## Related Examples

- [browser-app](../browser-app/) - Simple single app example
- [policy-as-code](../policy-as-code/) - Create access rules for your apps
- [publisher-aws](../publisher-aws/) - Deploy publishers in AWS