# Tutorial: Deploying NPA Publishers in Azure

This tutorial shows how to deploy Netskope NPA publishers in Microsoft Azure using Terraform. You'll create the Netskope publisher resource, generate a registration token, and deploy Azure VMs that automatically register with Netskope.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Azure VNet                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Private Subnet                        │    │
│  │   ┌─────────────┐         ┌─────────────┐               │    │
│  │   │  Publisher  │         │  Publisher  │               │    │
│  │   │  Primary    │         │  Secondary  │               │    │
│  │   └──────┬──────┘         └──────┬──────┘               │    │
│  │          │                       │                       │    │
│  │          │    Internal Apps      │                       │    │
│  │          │   ┌───────────┐       │                       │    │
│  │          └───│ 10.0.x.x  │───────┘                       │    │
│  │              └───────────┘                               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                          │                                       │
│                    NAT Gateway                                   │
│                          │                                       │
└──────────────────────────┼───────────────────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │  Netskope   │
                    │   Cloud     │
                    └─────────────┘
```

## Prerequisites

- Azure subscription with appropriate permissions
- Netskope tenant with API access
- Terraform 1.0+ installed
- Azure CLI installed and configured (`az login`)

## Network Requirements

Publishers require outbound HTTPS (443) access to:
- `*.goskope.com` - Netskope cloud services
- `*.netskope.com` - Netskope services

No inbound rules are required.

## Project Structure

```
publisher-azure/
├── main.tf              # Provider configurations
├── variables.tf         # Input variables
├── netskope.tf          # Netskope publisher resources
├── azure-network.tf     # VNet, subnets, NSG
├── azure-compute.tf     # Virtual machines
├── outputs.tf           # Output values
├── templates/
│   └── cloud-init.yaml  # Cloud-init configuration
└── terraform.tfvars     # Variable values
```

## Step 1: Provider Configuration

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskope/netskope"
      version = ">= 0.3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "netskope" {
  # Uses NETSKOPE_SERVER_URL and NETSKOPE_API_KEY environment variables
}

provider "azurerm" {
  features {}
}
```

## Step 2: Variables

Create `variables.tf`:

```hcl
# =============================================================================
# Azure Variables
# =============================================================================

variable "azure_location" {
  description = "Azure region to deploy publishers"
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-netskope-publishers"
}

variable "vnet_cidr" {
  description = "CIDR block for the VNet"
  type        = string
  default     = "10.100.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the publisher subnet"
  type        = string
  default     = "10.100.1.0/24"
}

variable "vm_size" {
  description = "Azure VM size for publishers"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# =============================================================================
# Netskope Variables
# =============================================================================

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "datacenter_name" {
  description = "Name identifier for this datacenter/location"
  type        = string
  default     = "azure-westus2"
}

variable "deploy_ha" {
  description = "Deploy secondary publisher for high availability"
  type        = bool
  default     = true
}

variable "publisher_docker_tag" {
  description = "Publisher Docker image tag (leave empty for latest)"
  type        = string
  default     = ""
}
```

## Step 3: Netskope Publisher Resources

Create `netskope.tf`:

```hcl
# =============================================================================
# Netskope Data Sources
# =============================================================================

data "netskope_npa_publishers_releases_list" "all" {}

locals {
  publisher_tag = var.publisher_docker_tag != "" ? var.publisher_docker_tag : [
    for r in data.netskope_npa_publishers_releases_list.all.data : r.docker_tag
    if r.name == "Latest"
  ][0]
}

# =============================================================================
# Netskope Publishers
# =============================================================================

resource "netskope_npa_publisher" "primary" {
  publisher_name = "${var.datacenter_name}-primary"
}

resource "netskope_npa_publisher_token" "primary" {
  publisher_id = netskope_npa_publisher.primary.id
}

resource "netskope_npa_publisher" "secondary" {
  count = var.deploy_ha ? 1 : 0

  publisher_name = "${var.datacenter_name}-secondary"
}

resource "netskope_npa_publisher_token" "secondary" {
  count = var.deploy_ha ? 1 : 0

  publisher_id = netskope_npa_publisher.secondary[0].id
}
```

## Step 4: Azure Network Infrastructure

Create `azure-network.tf`:

```hcl
# =============================================================================
# Resource Group
# =============================================================================

resource "azurerm_resource_group" "publisher" {
  name     = var.resource_group_name
  location = var.azure_location

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Virtual Network
# =============================================================================

resource "azurerm_virtual_network" "publisher" {
  name                = "${var.datacenter_name}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.publisher.location
  resource_group_name = azurerm_resource_group.publisher.name

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Subnet
# =============================================================================

resource "azurerm_subnet" "publisher" {
  name                 = "${var.datacenter_name}-subnet"
  resource_group_name  = azurerm_resource_group.publisher.name
  virtual_network_name = azurerm_virtual_network.publisher.name
  address_prefixes     = [var.subnet_cidr]
}

# =============================================================================
# NAT Gateway
# =============================================================================

resource "azurerm_public_ip" "nat" {
  name                = "${var.datacenter_name}-nat-ip"
  location            = azurerm_resource_group.publisher.location
  resource_group_name = azurerm_resource_group.publisher.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_nat_gateway" "publisher" {
  name                    = "${var.datacenter_name}-nat"
  location                = azurerm_resource_group.publisher.location
  resource_group_name     = azurerm_resource_group.publisher.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_nat_gateway_public_ip_association" "publisher" {
  nat_gateway_id       = azurerm_nat_gateway.publisher.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "publisher" {
  subnet_id      = azurerm_subnet.publisher.id
  nat_gateway_id = azurerm_nat_gateway.publisher.id
}

# =============================================================================
# Network Security Group
# =============================================================================

resource "azurerm_network_security_group" "publisher" {
  name                = "${var.datacenter_name}-nsg"
  location            = azurerm_resource_group.publisher.location
  resource_group_name = azurerm_resource_group.publisher.name

  # Outbound HTTPS to Netskope
  security_rule {
    name                       = "AllowHTTPSOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Outbound DNS
  security_rule {
    name                       = "AllowDNSOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Allow internal VNet traffic
  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_subnet_network_security_group_association" "publisher" {
  subnet_id                 = azurerm_subnet.publisher.id
  network_security_group_id = azurerm_network_security_group.publisher.id
}
```

## Step 5: Cloud-Init Template

Create `templates/cloud-init.yaml`:

```yaml
#cloud-config
package_update: true
package_upgrade: true

packages:
  - docker.io
  - curl

runcmd:
  - systemctl enable docker
  - systemctl start docker
  - sleep 10
  - docker pull netskope/publisher:${docker_tag}
  - docker run -d --name npa-publisher --restart always --net=host --cap-add NET_ADMIN -e PUBLISHER_TOKEN="${publisher_token}" netskope/publisher:${docker_tag}

final_message: "Netskope Publisher installation complete after $UPTIME seconds"
```

## Step 6: Azure Virtual Machines

Create `azure-compute.tf`:

```hcl
# =============================================================================
# Network Interfaces
# =============================================================================

resource "azurerm_network_interface" "primary" {
  name                = "${var.datacenter_name}-primary-nic"
  location            = azurerm_resource_group.publisher.location
  resource_group_name = azurerm_resource_group.publisher.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.publisher.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_network_interface" "secondary" {
  count = var.deploy_ha ? 1 : 0

  name                = "${var.datacenter_name}-secondary-nic"
  location            = azurerm_resource_group.publisher.location
  resource_group_name = azurerm_resource_group.publisher.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.publisher.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Environment = var.environment
  }
}

# =============================================================================
# Virtual Machines
# =============================================================================

resource "azurerm_linux_virtual_machine" "primary" {
  name                = "${var.datacenter_name}-publisher-primary"
  resource_group_name = azurerm_resource_group.publisher.name
  location            = azurerm_resource_group.publisher.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.primary.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml", {
    publisher_token = netskope_npa_publisher_token.primary.token
    docker_tag      = local.publisher_tag
  }))

  tags = {
    Name        = "${var.datacenter_name}-publisher-primary"
    Environment = var.environment
    Role        = "npa-publisher"
    ManagedBy   = "terraform"
  }
}

resource "azurerm_linux_virtual_machine" "secondary" {
  count = var.deploy_ha ? 1 : 0

  name                = "${var.datacenter_name}-publisher-secondary"
  resource_group_name = azurerm_resource_group.publisher.name
  location            = azurerm_resource_group.publisher.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.secondary[0].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml", {
    publisher_token = netskope_npa_publisher_token.secondary[0].token
    docker_tag      = local.publisher_tag
  }))

  tags = {
    Name        = "${var.datacenter_name}-publisher-secondary"
    Environment = var.environment
    Role        = "npa-publisher"
    ManagedBy   = "terraform"
  }
}
```

## Step 7: Outputs

Create `outputs.tf`:

```hcl
# =============================================================================
# Netskope Outputs
# =============================================================================

output "publisher_ids" {
  description = "Netskope publisher IDs"
  value = {
    primary   = netskope_npa_publisher.primary.id
    secondary = var.deploy_ha ? netskope_npa_publisher.secondary[0].id : null
  }
}

output "publisher_names" {
  description = "Netskope publisher names"
  value = {
    primary   = netskope_npa_publisher.primary.publisher_name
    secondary = var.deploy_ha ? netskope_npa_publisher.secondary[0].publisher_name : null
  }
}

# =============================================================================
# Azure Outputs
# =============================================================================

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.publisher.name
}

output "vnet_id" {
  description = "VNet ID"
  value       = azurerm_virtual_network.publisher.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = azurerm_subnet.publisher.id
}

output "vm_private_ips" {
  description = "VM private IP addresses"
  value = {
    primary   = azurerm_network_interface.primary.private_ip_address
    secondary = var.deploy_ha ? azurerm_network_interface.secondary[0].private_ip_address : null
  }
}

output "nat_public_ip" {
  description = "NAT Gateway public IP"
  value       = azurerm_public_ip.nat.ip_address
}
```

## Step 8: Deploy

Create `terraform.tfvars`:

```hcl
azure_location      = "westus2"
resource_group_name = "rg-netskope-publishers"
environment         = "production"
datacenter_name     = "azure-westus2"
vm_size             = "Standard_B2s"
deploy_ha           = true
ssh_public_key_path = "~/.ssh/id_rsa.pub"
```

Deploy:

```bash
terraform init
terraform plan
terraform apply
```

## Verifying the Deployment

### Check VM Status

```bash
# SSH to VM (if you have network access)
ssh azureuser@<private-ip>

# Check cloud-init status
cloud-init status

# View cloud-init logs
sudo cat /var/log/cloud-init-output.log

# Check Docker container
sudo docker ps
sudo docker logs npa-publisher
```

### Using Azure Serial Console

1. Navigate to the VM in Azure Portal
2. Go to **Help** > **Serial console**
3. Log in and check Docker status

## Cleanup

```bash
terraform destroy
```

## Next Steps

- [Private App Inventory Tutorial](./private-app-inventory.md) - Create applications
- [Policy as Code Tutorial](./policy-as-code.md) - Create access rules
- [Publisher GCP Tutorial](./publisher-gcp.md) - Deploy in GCP
