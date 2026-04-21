# Local Broker Management Example

This example demonstrates how to manage Netskope NPA Local Brokers using Terraform.

## What is a Local Broker?

A Local Broker (LBR) is a lightweight component that enables Netskope Private Access (NPA) to route traffic to private applications within your network. Local brokers provide additional routing flexibility for complex network topologies.

## Resources Demonstrated

| Resource | Description |
|----------|-------------|
| `netskope_npa_local_broker` | Create and manage local brokers |
| `netskope_npa_local_broker_config` | Configure tenant-wide hostname settings |
| `netskope_npa_local_broker_token` | Generate registration tokens |

## Data Sources Demonstrated

| Data Source | Description |
|-------------|-------------|
| `netskope_npa_local_brokers_list` | List all local brokers |
| `netskope_npa_local_broker_config` | Read current hostname config |
| `netskope_npa_local_broker` | Read a specific local broker |

## Usage

1. Set environment variables:

```bash
export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-key"
```

2. Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

3. Get the registration token (sensitive output):

```bash
terraform output -raw primary_broker_registration_token
```

## Access Modes

The `access_via_public_ip` attribute controls how clients can reach the broker:

| Value | Description |
|-------|-------------|
| `NONE` | No public IP access (default) |
| `OFF_PREM` | Allow off-premises clients via public IP |
| `ON_PREM` | Allow on-premises clients via public IP |
| `ON_OFF_PREM` | Allow both on and off-premises via public IP |

## Important Notes

- Registration tokens are **one-time use** - generate a new token for each broker registration
- The hostname configuration is **tenant-wide** and affects all local brokers
- Local broker names should be **unique** within your tenant