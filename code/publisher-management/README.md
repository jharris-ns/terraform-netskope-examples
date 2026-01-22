# Publisher Management Example

Demonstrates publisher lifecycle management including creating publishers, upgrade profiles, and alerts configuration.

## What This Creates

- 4 publishers across US West, US East, and EU regions
- Registration tokens for each publisher
- Weekly upgrade profile for production
- Daily upgrade profile for staging (beta releases)
- Alert configuration for upgrade and connection events

## Prerequisites

- Netskope tenant with REST API v2 access
- Infrastructure ready to deploy publishers (VMs, containers, etc.)

## Usage

1. Configure credentials:
   ```bash
   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
   export NETSKOPE_API_KEY="your-api-token"
   ```

2. Update `main.tf` with your configuration:
   - Publisher names for your locations
   - Alert email addresses
   - Upgrade schedule preferences

3. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. Get registration tokens:
   ```bash
   terraform output -json publisher_registration_tokens
   ```

5. Use tokens to register publisher VMs/containers with Netskope.

## Outputs

| Output | Description |
|--------|-------------|
| `publisher_registration_tokens` | Tokens for registering publishers (sensitive) |
| `upgrade_profiles` | Created upgrade profile details |
| `available_releases` | Available publisher versions |
| `all_publishers` | List of all publishers in tenant |

## Cleanup

```bash
terraform destroy
```

**Warning**: Destroying publishers will disconnect any applications using them.
