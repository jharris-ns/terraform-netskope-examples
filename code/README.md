# Netskope Terraform Examples

Ready-to-deploy Terraform configurations for Netskope Private Access (NPA).

## Prerequisites

- **Terraform** >= 1.0
- **Netskope tenant** with REST API v2 access enabled
- **API credentials** from Settings > Tools > REST API v2
- For AWS examples: AWS CLI configured with appropriate permissions

## Quick Start

### 1. Set Credentials

```bash
export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"
```

### 2. Choose an Example

```bash
cd browser-app   # or any other example directory
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Cleanup

```bash
terraform destroy
```

## Examples

| Example | Tutorial | Description |
|---------|----------|-------------|
| [browser-app/](./browser-app/) | - | Simple browser-accessible private app |
| [client-app/](./client-app/) | - | SSH, RDP, and database access via NPA client |
| [policy-as-code/](./policy-as-code/) | [Tutorial](../tutorials/policy-as-code.md) | NPA access policies with deny rules and team-based access |
| [private-app-inventory/](./private-app-inventory/) | [Tutorial](../tutorials/private-app-inventory.md) | Manage multiple apps at scale with variables |
| [publisher-aws/](./publisher-aws/) | [Tutorial](../tutorials/publisher-aws.md) | Deploy NPA publisher in AWS with VPC |
| [publisher-management/](./publisher-management/) | - | Publisher lifecycle, upgrades, and alerts |
| [full-deployment/](./full-deployment/) | - | Complete NPA setup with publishers, apps, and policies |

## Example Categories

### Getting Started
Start here if you're new to Netskope Terraform:
- **browser-app** - Simplest example, creates one browser-accessible app
- **client-app** - Creates apps for SSH, RDP, and database access

### Application Management
Managing multiple applications:
- **private-app-inventory** - Organize apps by tier (web, database, infrastructure)
- **full-deployment** - Complete setup including publishers and policies

### Publisher Deployment
Deploying NPA publishers:
- **publisher-aws** - Deploy in AWS with proper network isolation
- **publisher-management** - Manage publisher fleet, upgrades, alerts

### Access Control
Policy and rule management:
- **policy-as-code** - Team-based access rules, deny rules, catch-all policies

## Configuration

Most examples with variables support a `terraform.tfvars` file:

```bash
# Copy the example
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars

# Apply with your configuration
terraform apply
```

## Common Operations

### View Resources Before Applying
```bash
terraform plan
```

### Apply Changes
```bash
terraform apply
```

### View Outputs
```bash
terraform output
terraform output -json  # JSON format
```

### View Sensitive Outputs (e.g., tokens)
```bash
terraform output -json publisher_tokens
```

### Destroy Resources
```bash
terraform destroy
```

## Troubleshooting

### Authentication Errors

```
Error: failed to create client: missing api_key
```

Ensure environment variables are set:
```bash
echo $NETSKOPE_SERVER_URL
echo $NETSKOPE_API_KEY
```

### Publisher Not Found

```
Error: no publishers found
```

Deploy a publisher first, or check that your publisher is registered and connected.

### Rate Limiting

If you see 429 errors, wait a few seconds and retry. For large deployments, add `depends_on` between resources.

## Further Reading

- [Terraform Basics](../getting-started/terraform-basics.md) - New to Terraform?
- [Best Practices](../guides/best-practices.md) - Project structure and patterns
- [Provider Documentation](https://registry.terraform.io/providers/netskopeoss/netskope/latest/docs)
