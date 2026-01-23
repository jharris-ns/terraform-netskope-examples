# Publisher AWS Deployment

Deploy a Netskope NPA publisher in AWS with proper network isolation using VPC, private subnets, and NAT Gateway.

**Difficulty:** Intermediate

## Quick Start

```bash
cd examples/publisher-aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

# AWS credentials (using SSO)
aws sso login --profile your-profile
export AWS_PROFILE=your-profile

terraform init && terraform plan && terraform apply
```

## What This Creates

- VPC with public and private subnets
- Internet Gateway and NAT Gateway
- Security group (outbound-only, no inbound rules)
- EC2 instance running Netskope Publisher AMI
- Netskope publisher registration and token

## Architecture

```
+--------------------------------------------------+
|                       VPC                        |
|                                                  |
|   Private Subnet            Public Subnet        |
|  +----------------+       +------------------+   |
|  |                |       |                  |   |
|  |  +---------+   |       |   +---------+    |   |
|  |  |Publisher|------------>  | NAT GW  |    |   |
|  |  |  (EC2)  |   |       |   +----+----+    |   |
|  |  +---------+   |       |        |         |   |
|  |                |       |        v         |   |
|  +----------------+       |   +---------+    |   |
|                           |   |   IGW   |    |   |
|                           |   +----+----+    |   |
|                           +--------+---------+   |
+----------------------------+-------+-------------+
                                     |
                                     v
                            Netskope NewEdge
```

**Traffic Flow:**
1. Publisher (private subnet) sends outbound traffic to NAT Gateway
2. NAT Gateway forwards to Internet Gateway
3. Internet Gateway routes to Netskope NewEdge

**Key Points:**
- Publishers in **private subnets** with no direct internet access
- **NAT Gateways** provide outbound-only connectivity
- **Security groups** allow only outbound HTTPS (443) - no inbound rules
- NewEdge routes traffic to the publisher automatically

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured or SSO profile set up
- Subscribed to [Netskope Publisher AMI](https://aws.amazon.com/marketplace) in AWS Marketplace

## Network Requirements

Publishers require outbound HTTPS (443) access to:
- `*.goskope.com` - Netskope cloud services
- `*.netskope.com` - Netskope services

No inbound rules are required.

## File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration and AMI lookup |
| `variables.tf` | Input variables |
| `netskope.tf` | Netskope publisher resources |
| `aws.tf` | VPC, subnets, NAT, security group, EC2 |
| `outputs.tf` | Output values |

## How It Works

### Finding the Latest AMI

The AMI is looked up dynamically to always get the latest version:

```hcl
# Pattern: Dynamic AMI lookup
data "aws_ami" "netskope_publisher" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["*Netskope Private Access Publisher*"]
  }
}
```

### User Data for Registration

The publisher registers automatically using a token passed via user_data:

```hcl
resource "aws_instance" "publisher" {
  ami = data.aws_ami.netskope_publisher.id

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    /opt/netskope/npa-publisher-wizard -token ${netskope_npa_publisher_token.this.token}
  EOF
  )

  # Ignore AMI changes to prevent recreation on AMI updates
  lifecycle {
    ignore_changes = [ami]
  }
}
```

## Common Mistakes

| Mistake | What Happens | Fix |
|---------|--------------|-----|
| Wrong AMI filter pattern | No AMI found | Use `*Netskope Private Access Publisher*` with wildcards |
| Hardcoded AMI ID | Region-specific, outdated | Use `aws_ami` data source |
| Not subscribed to AMI | Access denied | Subscribe in AWS Marketplace first |
| Publisher in public subnet | Security risk | Use private subnet with NAT Gateway |
| Using `.id` instead of `.publisher_id` | Attribute not found | Use `netskope_npa_publisher.this.publisher_id` |
| Missing `ignore_changes = [ami]` | Plan shows changes after AMI updates | Add lifecycle block |

## Example terraform.tfvars

```hcl
aws_region     = "us-west-2"
publisher_name = "aws-usw2-publisher"
instance_type  = "t3.medium"

vpc_cidr            = "10.100.0.0/16"
public_subnet_cidr  = "10.100.0.0/24"
private_subnet_cidr = "10.100.1.0/24"
```

## Outputs

| Output | Description |
|--------|-------------|
| `publisher_id` | Netskope publisher ID |
| `instance_id` | EC2 instance ID |
| `private_ip` | Publisher private IP |
| `nat_gateway_ip` | NAT Gateway public IP |
| `ami_used` | AMI ID used for deployment |
| `ami_name` | AMI name (includes version) |

## Verifying the Deployment

After deployment, the publisher will register within a few minutes:

1. Navigate to **Settings** > **Security Cloud Platform** > **App Definition** > **NPA Publishers**
2. Verify publisher shows "Connected" status

## Multi-Region Deployment

For global coverage, deploy publishers across multiple AWS regions using provider aliases:

```hcl
provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "publisher_us_west" {
  source = "./modules/publisher"
  providers = { aws = aws.us_west_2 }
  # ...
}

module "publisher_us_east" {
  source = "./modules/publisher"
  providers = { aws = aws.us_east_1 }
  # ...
}
```

## Cleanup

```bash
terraform destroy
```

**Warning**: This will terminate the EC2 instance and delete all AWS resources.

## Related Examples

- [browser-app](../browser-app/) - Create apps using this publisher
- [private-app-inventory](../private-app-inventory/) - Manage multiple apps
- [policy-as-code](../policy-as-code/) - Create access rules