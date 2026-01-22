# Publisher AWS Example

Deploys a Netskope NPA publisher in AWS with proper network isolation using VPC, private subnets, and NAT Gateway.

**Full Tutorial**: [tutorials/publisher-aws.md](../../tutorials/publisher-aws.md)

## What This Creates

- VPC with public and private subnets
- Internet Gateway and NAT Gateway
- Security group (outbound-only, no inbound rules)
- EC2 instance running Netskope Publisher AMI
- Netskope publisher registration

## Architecture

```
┌─────────────────────────────────────────┐
│                  VPC                    │
│  ┌─────────────────┐  ┌──────────────┐  │
│  │  Public Subnet  │  │Private Subnet│  │
│  │  ┌───────────┐  │  │ ┌──────────┐ │  │
│  │  │ NAT GW    │  │  │ │Publisher │ │  │
│  │  └─────┬─────┘  │  │ │  (EC2)   │ │  │
│  └────────┼────────┘  │ └────┬─────┘ │  │
│           │           └──────┼───────┘  │
│  ┌────────┴────────┐         │          │
│  │ Internet Gateway│←────────┘          │
│  └────────┬────────┘ (outbound only)    │
└───────────┼─────────────────────────────┘
            ↓
     Netskope NewEdge
```

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured or SSO profile set up
- Subscribed to Netskope Publisher AMI in AWS Marketplace

## Usage

1. Configure credentials:
   ```bash
   # Netskope
   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
   export NETSKOPE_API_KEY="your-api-token"

   # AWS (using SSO)
   aws sso login --profile your-profile
   export AWS_PROFILE=your-profile
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

## Outputs

| Output | Description |
|--------|-------------|
| `publisher_id` | Netskope publisher ID |
| `instance_id` | EC2 instance ID |
| `private_ip` | Publisher private IP |
| `nat_gateway_ip` | NAT Gateway public IP |
| `ami_used` | AMI ID used for deployment |

## Cleanup

```bash
terraform destroy
```

**Warning**: This will terminate the EC2 instance and delete all AWS resources.
