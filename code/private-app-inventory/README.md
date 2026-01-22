# Private App Inventory Example

Manages multiple private applications at scale using variables and loops. Organizes apps by tier (web, database, infrastructure).

**Full Tutorial**: [tutorials/private-app-inventory.md](../../tutorials/private-app-inventory.md)

## What This Creates

- Web tier applications (HTTPS, browser-accessible)
- Database tier applications (PostgreSQL, Redis, MongoDB)
- Infrastructure applications (SSH, RDP)
- Consistent tagging across all applications
- High-availability with multiple publishers

## File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration |
| `variables.tf` | Input variable definitions |
| `data.tf` | Publisher lookup |
| `apps-web.tf` | Web tier application resources |
| `apps-database.tf` | Database tier application resources |
| `apps-infrastructure.tf` | Infrastructure application resources |
| `outputs.tf` | Output values |
| `terraform.tfvars.example` | Example variable values |

## Prerequisites

- At least one registered NPA publisher
- Publisher names known for configuration

## Usage

1. Configure credentials:
   ```bash
   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
   export NETSKOPE_API_KEY="your-api-token"
   ```

2. Copy and configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
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

## Cleanup

```bash
terraform destroy
```
