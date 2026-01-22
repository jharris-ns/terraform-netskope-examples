# Client App Example

Creates private applications that require the Netskope NPA client for access. Ideal for non-HTTP protocols.

## What This Creates

- SSH bastion host access (port 22)
- RDP Windows server access (port 3389)
- PostgreSQL database access (port 5432)

All apps require the NPA client - no browser access.

## Prerequisites

- At least one registered NPA publisher
- Netskope NPA client installed on user devices

## Usage

1. Configure credentials:
   ```bash
   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
   export NETSKOPE_API_KEY="your-api-token"
   ```

2. Update `main.tf` with your server details:
   - `private_app_hostname` - The hostname users will connect to
   - `real_host` - The actual IP of the backend server
   - `protocols.port` - The port for each service

3. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Connecting

After deployment, users connect via the NPA client:

```bash
# SSH
ssh user@bastion.internal.company.com

# RDP (via Windows Remote Desktop)
# Connect to: admin-win.internal.company.com

# PostgreSQL
psql -h postgres.internal.company.com -U dbuser -d mydb
```

## Outputs

| Output | Description |
|--------|-------------|
| `ssh_app_hostname` | Hostname for SSH access |
| `rdp_app_hostname` | Hostname for RDP access |
| `database_app_hostname` | Hostname for database access |

## Cleanup

```bash
terraform destroy
```
