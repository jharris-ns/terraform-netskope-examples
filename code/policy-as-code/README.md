# Policy as Code Example

Manages NPA access policies using Terraform including policy groups, deny rules, team-based access, and catch-all rules.

**Full Tutorial**: [tutorials/policy-as-code.md](../../tutorials/policy-as-code.md)

## What This Creates

- Deny rules for blocked users (evaluated first)
- Admin access rules for infrastructure and databases
- Developer access rules for web applications
- DBA access rules for databases
- General browser access for portal apps
- Catch-all deny rule (deny-by-default)

## Rule Evaluation Order

```
1. Deny blocked users     ← First (always deny terminated/quarantined)
2. Admin SSH access       ← Privileged access
3. Admin database access
4. Developer web access   ← Team-based access
5. DBA database access
6. General browser access ← Broad access
7. Deny all other         ← Last (catch-all deny)
```

## File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration |
| `variables.tf` | User groups and app tags |
| `data.tf` | Discover existing apps and groups |
| `rules-deny.tf` | Deny rules (blocked users) |
| `rules-admin.tf` | Admin/privileged access rules |
| `rules-teams.tf` | Team-based access rules |
| `rules-general.tf` | General access and catch-all |
| `outputs.tf` | Rule order and app categories |

## Prerequisites

- Private applications already created with appropriate tags
- User groups configured in your IdP
- IdP groups synced to Netskope

## Usage

1. Configure credentials:
   ```bash
   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
   export NETSKOPE_API_KEY="your-api-token"
   ```

2. Copy and configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit with your IdP group names and app tags
   ```

3. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Cleanup

```bash
terraform destroy
```

**Warning**: Destroying rules may disrupt user access. Consider disabling rules first.
