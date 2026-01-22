# Tutorial: Deploying NPA Publishers in AWS

This tutorial shows how to deploy Netskope NPA publishers in AWS using the Marketplace AMI. You'll learn how to find the latest AMI and deploy publishers across multiple regions.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              AWS Region                                      │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                                 VPC                                    │  │
│  │                                                                        │  │
│  │    Availability Zone A              Availability Zone B                │  │
│  │   ┌────────────────────┐           ┌────────────────────┐              │  │
│  │   │   Private Subnet   │           │   Private Subnet   │              │  │
│  │   │   ┌──────────┐     │           │     ┌──────────┐   │              │  │
│  │   │   │Publisher │     │           │     │Publisher │   │              │  │
│  │   │   │  (EC2)   │     │           │     │  (EC2)   │   │              │  │
│  │   │   │ SG: 443↑ │     │           │     │ SG: 443↑ │   │              │  │
│  │   │   └────┬─────┘     │           │     └────┬─────┘   │              │  │
│  │   └────────┼───────────┘           └──────────┼─────────┘              │  │
│  │            │                                  │                        │  │
│  │            ▼ Private RT                       ▼ Private RT             │  │
│  │                                                                        │  │
│  │   ┌────────────────────┐           ┌────────────────────┐              │  │
│  │   │   Public Subnet    │           │   Public Subnet    │              │  │
│  │   │   ┌──────────┐     │           │     ┌──────────┐   │              │  │
│  │   │   │  NAT GW  │     │           │     │  NAT GW  │   │              │  │
│  │   │   └────┬─────┘     │           │     └────┬─────┘   │              │  │
│  │   └────────┼───────────┘           └──────────┼─────────┘              │  │
│  │            │                                  │                        │  │
│  │            ▼ Public RT                        ▼ Public RT              │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                          │                     │                             │
│                          └──────────┬──────────┘                             │
│                              ┌──────┴──────┐                                 │
│                              │ Internet GW │                                 │
│                              └──────┬──────┘                                 │
└─────────────────────────────────────┼────────────────────────────────────────┘
                                      │
                                      │ HTTPS (443) Outbound Only
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                          Netskope NewEdge Network                            │
│                                                                              │
│      ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐           │
│      │  PoP     │    │  PoP     │    │  PoP     │    │  PoP     │           │
│      │ (Global) │    │ (Global) │    │ (Global) │    │ (Global) │           │
│      └──────────┘    └──────────┘    └──────────┘    └──────────┘           │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Key Points:**
- Publishers deployed in **private subnets** with no direct internet access
- **NAT Gateways** in public subnets provide outbound-only connectivity
- **Security groups** allow only outbound HTTPS (443) - no inbound rules
- Deploy across **multiple Availability Zones** for high availability
- NewEdge automatically routes traffic to the nearest healthy publisher

## Prerequisites

- AWS account with appropriate permissions
- Netskope tenant with API access
- Terraform 1.0+ installed
- Subscribe to the [Netskope Publisher AMI](https://aws.amazon.com/marketplace/pp/prodview-xxxxxxx) in AWS Marketplace

## Run the Code

Ready-to-deploy Terraform configurations are available in [`code/publisher-aws/`](../code/publisher-aws/). You can deploy immediately and follow along with this tutorial for detailed explanations.

```bash
cd code/publisher-aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform plan && terraform apply
```

## Network Requirements

Publishers require outbound HTTPS (443) access to:
- `*.goskope.com` - Netskope cloud services
- `*.netskope.com` - Netskope services

No inbound rules are required from the internet.

## Finding the Netskope Publisher AMI

The Netskope Publisher AMI is available in AWS Marketplace. Use this data source to find the latest version:

```hcl
data "aws_ami" "netskope_publisher" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["*Netskope Private Access Publisher*"]
  }
}

output "ami_id" {
  value = data.aws_ami.netskope_publisher.id
}

output "ami_name" {
  value = data.aws_ami.netskope_publisher.name
}
```

> **Common Mistakes - AMI Lookup**
>
> | Mistake | What Happens | Fix |
> |---------|--------------|-----|
> | Wrong filter pattern | No AMI found | Use `*Netskope Private Access Publisher*` (include wildcards) |
> | Using specific AMI ID | Hardcoded, region-specific, outdated | Use `aws_ami` data source with `most_recent = true` |
> | Wrong owner | No results | Use `owners = ["aws-marketplace"]` |
> | Not subscribed to AMI | Access denied error | Subscribe in [AWS Marketplace](https://aws.amazon.com/marketplace) first |

## Simple Single-Region Deployment

### Project Structure

```
publisher-aws/
├── main.tf              # Provider and AMI lookup
├── variables.tf         # Input variables
├── netskope.tf          # Netskope publisher resources
├── aws.tf               # VPC and EC2 resources
├── outputs.tf           # Output values
└── terraform.tfvars     # Variable values
```

### main.tf

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "netskope" {}

provider "aws" {
  region = var.aws_region
}

# Find the latest Netskope Publisher AMI
data "aws_ami" "netskope_publisher" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["*Netskope Private Access Publisher*"]
  }
}
```

### variables.tf

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.100.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR (for NAT Gateway)"
  type        = string
  default     = "10.100.0.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR (for Publisher)"
  type        = string
  default     = "10.100.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "publisher_name" {
  description = "Name for the Netskope publisher"
  type        = string
}
```

### netskope.tf

```hcl
# See: ../resources/npa_publisher.md
resource "netskope_npa_publisher" "this" {
  publisher_name = var.publisher_name
}

# See: ../resources/npa_publisher_token.md
resource "netskope_npa_publisher_token" "this" {
  publisher_id = netskope_npa_publisher.this.publisher_id
}
```

> **Common Mistakes - Netskope Resources**
>
> | Mistake | Error You'll See | Fix |
> |---------|------------------|-----|
> | Using `.id` instead of `.publisher_id` | Attribute not found | Use `netskope_npa_publisher.this.publisher_id` |
> | Missing publisher_id in token resource | Invalid argument | Token requires `publisher_id` from publisher resource |
> | Duplicate publisher name | Name already exists | Use unique names per publisher |

### aws.tf

```hcl
# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.publisher_name}-vpc" }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.publisher_name}-igw" }
}

# Public Subnet (for NAT Gateway)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = false

  tags = { Name = "${var.publisher_name}-public" }
}

# Private Subnet (for Publisher)
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.this.id
  cidr_block = var.private_subnet_cidr

  tags = { Name = "${var.publisher_name}-private" }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "${var.publisher_name}-nat-eip" }
}

# NAT Gateway
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = { Name = "${var.publisher_name}-nat" }

  depends_on = [aws_internet_gateway.this]
}

# Public Route Table (IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.publisher_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table (NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "${var.publisher_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Group - Outbound only
resource "aws_security_group" "publisher" {
  name        = "${var.publisher_name}-sg"
  description = "Netskope Publisher - outbound only"
  vpc_id      = aws_vpc.this.id

  # No ingress rules - no inbound traffic allowed

  egress {
    description = "HTTPS to Netskope NewEdge"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.publisher_name}-sg" }
}

# EC2 Instance in Private Subnet
resource "aws_instance" "publisher" {
  ami                    = data.aws_ami.netskope_publisher.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.publisher.id]

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    /opt/netskope/npa-publisher-wizard -token ${netskope_npa_publisher_token.this.token}
  EOF
  )

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # Enforce IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = { Name = var.publisher_name }

  lifecycle {
    ignore_changes = [ami]
  }
}
```

> **Common Mistakes - AWS Infrastructure**
>
> | Mistake | What Happens | Fix |
> |---------|--------------|-----|
> | Publisher in public subnet | Security risk, unnecessary exposure | Use private subnet with NAT Gateway |
> | Using `user_data` with base64 | Encoding warning, may fail | Use `user_data_base64 = base64encode(...)` |
> | Missing NAT Gateway | Publisher can't reach NewEdge | Add NAT Gateway in public subnet |
> | Inbound rules in security group | Unnecessary attack surface | Only outbound 443 (HTTPS) and 53 (DNS) needed |
> | Missing `ignore_changes = [ami]` | Plan shows changes after AMI updates | Add lifecycle block to ignore AMI drift |

### outputs.tf

```hcl
output "publisher_id" {
  description = "Netskope publisher ID"
  value       = netskope_npa_publisher.this.publisher_id
}

output "ami_used" {
  description = "AMI ID used for deployment"
  value       = data.aws_ami.netskope_publisher.id
}

output "ami_name" {
  description = "AMI name"
  value       = data.aws_ami.netskope_publisher.name
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.publisher.id
}

output "private_ip" {
  description = "Publisher private IP"
  value       = aws_instance.publisher.private_ip
}

output "nat_gateway_ip" {
  description = "NAT Gateway public IP (outbound traffic)"
  value       = aws_eip.nat.public_ip
}
```

### terraform.tfvars

```hcl
aws_region     = "us-west-2"
publisher_name = "aws-usw2-publisher"
instance_type  = "t3.medium"
```

### Deploy

```bash
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding netskope/netskope versions matching ">= 0.3.0"...
- Finding hashicorp/aws versions matching ">= 5.0"...
- Installing netskope/netskope v0.3.5...
- Installing hashicorp/aws v5.80.0...

Terraform has been successfully initialized!
```

```bash
terraform plan
```

Expected output:
```
data.aws_ami.netskope_publisher: Reading...
data.aws_ami.netskope_publisher: Read complete after 1s [id=ami-072134b99f4e06bd4]

Terraform will perform the following actions:

  # aws_eip.nat will be created
  # aws_instance.publisher will be created
  # aws_internet_gateway.this will be created
  # aws_nat_gateway.this will be created
  # aws_route_table.private will be created
  # aws_route_table.public will be created
  # aws_security_group.publisher will be created
  # aws_subnet.private will be created
  # aws_subnet.public will be created
  # aws_vpc.this will be created
  # netskope_npa_publisher.this will be created
  # netskope_npa_publisher_token.this will be created

Plan: 14 to add, 0 to change, 0 to destroy.
```

```bash
terraform apply
```

Expected output after confirmation:
```
netskope_npa_publisher.this: Creating...
netskope_npa_publisher.this: Creation complete after 2s
netskope_npa_publisher_token.this: Creating...
netskope_npa_publisher_token.this: Creation complete after 1s
aws_vpc.this: Creating...
...
aws_instance.publisher: Creating...
aws_instance.publisher: Still creating... [10s elapsed]
aws_instance.publisher: Creation complete after 35s

Apply complete! Resources: 14 added, 0 changed, 0 destroyed.

Outputs:

ami_name = "Netskope Private Access Publisher 133.0.0.10466..."
ami_used = "ami-072134b99f4e06bd4"
instance_id = "i-0abc123def456789"
nat_gateway_ip = "52.10.123.45"
private_ip = "10.100.1.50"
publisher_id = "12345"
```

## Multi-Region Deployment

Deploy publishers across multiple AWS regions for global coverage and redundancy:

```
                              Netskope NewEdge
                         (Global PoP Network)
                                  │
            ┌─────────────────────┼─────────────────────┐
            │                     │                     │
            ▼                     ▼                     ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│   AWS us-west-2   │  │   AWS us-east-1   │  │   AWS eu-west-1   │
│  ┌─────────────┐  │  │  ┌─────────────┐  │  │  ┌─────────────┐  │
│  │  Publisher  │  │  │  │  Publisher  │  │  │  │  Publisher  │  │
│  │ (Oregon)    │  │  │  │ (Virginia)  │  │  │  │ (Ireland)   │  │
│  └─────────────┘  │  │  └─────────────┘  │  │  └─────────────┘  │
│        │          │  │        │          │  │        │          │
│        ▼          │  │        ▼          │  │        ▼          │
│  ┌─────────────┐  │  │  ┌─────────────┐  │  │  ┌─────────────┐  │
│  │ Private Apps│  │  │  │ Private Apps│  │  │  │ Private Apps│  │
│  │ (West Coast)│  │  │  │ (East Coast)│  │  │  │  (Europe)   │  │
│  └─────────────┘  │  │  └─────────────┘  │  │  └─────────────┘  │
└───────────────────┘  └───────────────────┘  └───────────────────┘
```

Users connect to NewEdge, which routes to the appropriate regional publisher based on application assignment.

Deploy using provider aliases:

### main.tf (Multi-Region)

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "netskope" {}

# US West (Oregon)
provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

# US East (Virginia)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# EU West (Ireland)
provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}
```

### variables.tf (Multi-Region)

```hcl
variable "regions" {
  description = "Map of regions to deploy publishers"
  type = map(object({
    vpc_cidr            = string
    public_subnet_cidr  = string
    private_subnet_cidr = string
    instance_type       = string
  }))
  default = {
    us-west-2 = {
      vpc_cidr            = "10.100.0.0/16"
      public_subnet_cidr  = "10.100.0.0/24"
      private_subnet_cidr = "10.100.1.0/24"
      instance_type       = "t3.medium"
    }
    us-east-1 = {
      vpc_cidr            = "10.101.0.0/16"
      public_subnet_cidr  = "10.101.0.0/24"
      private_subnet_cidr = "10.101.1.0/24"
      instance_type       = "t3.medium"
    }
    eu-west-1 = {
      vpc_cidr            = "10.102.0.0/16"
      public_subnet_cidr  = "10.102.0.0/24"
      private_subnet_cidr = "10.102.1.0/24"
      instance_type       = "t3.medium"
    }
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}
```

### modules/publisher/main.tf

Create a reusable module for the publisher infrastructure:

```hcl
variable "publisher_name" {
  type = string
}

variable "publisher_token" {
  type      = string
  sensitive = true
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidr" {
  type = string
}

variable "private_subnet_cidr" {
  type = string
}

variable "instance_type" {
  type = string
}

# Find the latest AMI in this region
data "aws_ami" "netskope_publisher" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["*Netskope Private Access Publisher*"]
  }
}

data "aws_region" "current" {}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.publisher_name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.publisher_name}-igw" }
}

# Public Subnet (for NAT Gateway)
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.this.id
  cidr_block = var.public_subnet_cidr

  tags = { Name = "${var.publisher_name}-public" }
}

# Private Subnet (for Publisher)
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.this.id
  cidr_block = var.private_subnet_cidr

  tags = { Name = "${var.publisher_name}-private" }
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "${var.publisher_name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = { Name = "${var.publisher_name}-nat" }

  depends_on = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.publisher_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "${var.publisher_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Group - Outbound only
resource "aws_security_group" "publisher" {
  name        = "${var.publisher_name}-sg"
  description = "Netskope Publisher - outbound only"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.publisher_name}-sg" }
}

# EC2 Instance in Private Subnet
resource "aws_instance" "this" {
  ami                    = data.aws_ami.netskope_publisher.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.publisher.id]

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    /opt/netskope/npa-publisher-wizard -token ${var.publisher_token}
  EOF
  )

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # Enforce IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = { Name = var.publisher_name }

  lifecycle {
    ignore_changes = [ami]
  }
}

output "ami_id" {
  value = data.aws_ami.netskope_publisher.id
}

output "ami_name" {
  value = data.aws_ami.netskope_publisher.name
}

output "region" {
  value = data.aws_region.current.name
}

output "instance_id" {
  value = aws_instance.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "nat_gateway_ip" {
  value = aws_eip.nat.public_ip
}
```

### publishers.tf (Multi-Region)

```hcl
# =============================================================================
# Netskope Publishers
# =============================================================================

resource "netskope_npa_publisher" "us_west_2" {
  publisher_name = "${var.environment}-us-west-2"
}

resource "netskope_npa_publisher_token" "us_west_2" {
  publisher_id = netskope_npa_publisher.us_west_2.publisher_id
}

resource "netskope_npa_publisher" "us_east_1" {
  publisher_name = "${var.environment}-us-east-1"
}

resource "netskope_npa_publisher_token" "us_east_1" {
  publisher_id = netskope_npa_publisher.us_east_1.publisher_id
}

resource "netskope_npa_publisher" "eu_west_1" {
  publisher_name = "${var.environment}-eu-west-1"
}

resource "netskope_npa_publisher_token" "eu_west_1" {
  publisher_id = netskope_npa_publisher.eu_west_1.publisher_id
}

# =============================================================================
# AWS Infrastructure - US West 2
# =============================================================================

module "publisher_us_west_2" {
  source = "./modules/publisher"
  providers = {
    aws = aws.us_west_2
  }

  publisher_name      = "${var.environment}-us-west-2"
  publisher_token     = netskope_npa_publisher_token.us_west_2.token
  vpc_cidr            = var.regions["us-west-2"].vpc_cidr
  public_subnet_cidr  = var.regions["us-west-2"].public_subnet_cidr
  private_subnet_cidr = var.regions["us-west-2"].private_subnet_cidr
  instance_type       = var.regions["us-west-2"].instance_type
}

# =============================================================================
# AWS Infrastructure - US East 1
# =============================================================================

module "publisher_us_east_1" {
  source = "./modules/publisher"
  providers = {
    aws = aws.us_east_1
  }

  publisher_name      = "${var.environment}-us-east-1"
  publisher_token     = netskope_npa_publisher_token.us_east_1.token
  vpc_cidr            = var.regions["us-east-1"].vpc_cidr
  public_subnet_cidr  = var.regions["us-east-1"].public_subnet_cidr
  private_subnet_cidr = var.regions["us-east-1"].private_subnet_cidr
  instance_type       = var.regions["us-east-1"].instance_type
}

# =============================================================================
# AWS Infrastructure - EU West 1
# =============================================================================

module "publisher_eu_west_1" {
  source = "./modules/publisher"
  providers = {
    aws = aws.eu_west_1
  }

  publisher_name      = "${var.environment}-eu-west-1"
  publisher_token     = netskope_npa_publisher_token.eu_west_1.token
  vpc_cidr            = var.regions["eu-west-1"].vpc_cidr
  public_subnet_cidr  = var.regions["eu-west-1"].public_subnet_cidr
  private_subnet_cidr = var.regions["eu-west-1"].private_subnet_cidr
  instance_type       = var.regions["eu-west-1"].instance_type
}
```

### outputs.tf (Multi-Region)

```hcl
output "publishers" {
  description = "Publisher details by region"
  value = {
    us-west-2 = {
      publisher_id   = netskope_npa_publisher.us_west_2.publisher_id
      ami_id         = module.publisher_us_west_2.ami_id
      ami_name       = module.publisher_us_west_2.ami_name
      instance_id    = module.publisher_us_west_2.instance_id
      private_ip     = module.publisher_us_west_2.private_ip
      nat_gateway_ip = module.publisher_us_west_2.nat_gateway_ip
    }
    us-east-1 = {
      publisher_id   = netskope_npa_publisher.us_east_1.publisher_id
      ami_id         = module.publisher_us_east_1.ami_id
      ami_name       = module.publisher_us_east_1.ami_name
      instance_id    = module.publisher_us_east_1.instance_id
      private_ip     = module.publisher_us_east_1.private_ip
      nat_gateway_ip = module.publisher_us_east_1.nat_gateway_ip
    }
    eu-west-1 = {
      publisher_id   = netskope_npa_publisher.eu_west_1.publisher_id
      ami_id         = module.publisher_eu_west_1.ami_id
      ami_name       = module.publisher_eu_west_1.ami_name
      instance_id    = module.publisher_eu_west_1.instance_id
      private_ip     = module.publisher_eu_west_1.private_ip
      nat_gateway_ip = module.publisher_eu_west_1.nat_gateway_ip
    }
  }
}
```

## AMI Availability by Region

The Netskope Publisher AMI is replicated across AWS regions. The `aws_ami` data source automatically finds the correct AMI ID for each region. When you use provider aliases, each region's data source returns the AMI ID specific to that region.

```hcl
# This returns different AMI IDs depending on which provider is used
data "aws_ami" "netskope_publisher" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["*Netskope Private Access Publisher*"]
  }
}
```

## Verifying the Deployment

After deployment, publishers will register with Netskope within a few minutes:

1. Navigate to **Settings** > **Security Cloud Platform** > **App Definition** > **NPA Publishers**
2. Verify publishers show "Connected" status

## Cleanup

```bash
terraform destroy
```

## Next Steps

- [Private App Inventory Tutorial](./private-app-inventory.md) - Create applications
- [Policy as Code Tutorial](./policy-as-code.md) - Create access rules
- [Best Practices Guide](../guides/best-practices.md) - Project organization patterns
