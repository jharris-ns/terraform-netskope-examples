# Tutorial: Deploying NPA Publishers in GCP

This tutorial shows how to deploy Netskope NPA publishers in Google Cloud Platform using Terraform. You'll create the Netskope publisher resource, generate a registration token, and deploy Compute Engine instances that automatically register with Netskope.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        GCP VPC                                   │
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
│                    Cloud NAT                                     │
│                          │                                       │
└──────────────────────────┼───────────────────────────────────────┘
                           │
                    Cloud Router
                           │
                    ┌──────┴──────┐
                    │  Netskope   │
                    │   Cloud     │
                    └─────────────┘
```

## Prerequisites

- GCP project with appropriate permissions
- Netskope tenant with API access
- Terraform 1.0+ installed
- gcloud CLI configured (`gcloud auth application-default login`)

## Network Requirements

Publishers require outbound HTTPS (443) access to:
- `*.goskope.com` - Netskope cloud services
- `*.netskope.com` - Netskope services

No inbound rules are required.

## Project Structure

```
publisher-gcp/
├── main.tf              # Provider configurations
├── variables.tf         # Input variables
├── netskope.tf          # Netskope publisher resources
├── gcp-network.tf       # VPC, subnets, firewall
├── gcp-compute.tf       # Compute instances
├── outputs.tf           # Output values
├── templates/
│   └── startup-script.sh.tpl  # Startup script
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
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "netskope" {
  # Uses NETSKOPE_SERVER_URL and NETSKOPE_API_KEY environment variables
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}
```

## Step 2: Variables

Create `variables.tf`:

```hcl
# =============================================================================
# GCP Variables
# =============================================================================

variable "gcp_project" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region to deploy publishers"
  type        = string
  default     = "us-west1"
}

variable "gcp_zone" {
  description = "GCP zone for instances"
  type        = string
  default     = "us-west1-a"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC subnet"
  type        = string
  default     = "10.100.0.0/24"
}

variable "machine_type" {
  description = "GCP machine type for publishers"
  type        = string
  default     = "e2-medium"
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
  default     = "gcp-usw1"
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

## Step 4: GCP Network Infrastructure

Create `gcp-network.tf`:

```hcl
# =============================================================================
# VPC Network
# =============================================================================

resource "google_compute_network" "publisher" {
  name                    = "${var.datacenter_name}-vpc"
  auto_create_subnetworks = false
  project                 = var.gcp_project
}

# =============================================================================
# Subnet
# =============================================================================

resource "google_compute_subnetwork" "publisher" {
  name          = "${var.datacenter_name}-subnet"
  ip_cidr_range = var.vpc_cidr
  region        = var.gcp_region
  network       = google_compute_network.publisher.id

  private_ip_google_access = true
}

# =============================================================================
# Cloud Router (required for Cloud NAT)
# =============================================================================

resource "google_compute_router" "publisher" {
  name    = "${var.datacenter_name}-router"
  region  = var.gcp_region
  network = google_compute_network.publisher.id
}

# =============================================================================
# Cloud NAT
# =============================================================================

resource "google_compute_router_nat" "publisher" {
  name                               = "${var.datacenter_name}-nat"
  router                             = google_compute_router.publisher.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# =============================================================================
# Firewall Rules
# =============================================================================

# Allow outbound HTTPS
resource "google_compute_firewall" "allow_https_egress" {
  name    = "${var.datacenter_name}-allow-https-egress"
  network = google_compute_network.publisher.name

  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["npa-publisher"]
}

# Allow outbound DNS
resource "google_compute_firewall" "allow_dns_egress" {
  name    = "${var.datacenter_name}-allow-dns-egress"
  network = google_compute_network.publisher.name

  direction = "EGRESS"

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["npa-publisher"]
}

# Allow internal traffic
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.datacenter_name}-allow-internal"
  network = google_compute_network.publisher.name

  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc_cidr]
  target_tags   = ["npa-publisher"]
}

# Allow SSH from IAP (for troubleshooting)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.datacenter_name}-allow-iap-ssh"
  network = google_compute_network.publisher.name

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["npa-publisher"]
}
```

## Step 5: Startup Script Template

Create `templates/startup-script.sh.tpl`:

```bash
#!/bin/bash
set -e

# Log output
exec > >(tee /var/log/publisher-startup.log) 2>&1

echo "=== Starting Netskope Publisher Installation ==="
echo "Timestamp: $(date)"

# Install Docker
echo "Installing Docker..."
apt-get update
apt-get install -y docker.io
systemctl enable docker
systemctl start docker

# Wait for Docker
sleep 10

# Pull and run publisher
echo "Pulling publisher image..."
docker pull netskope/publisher:${docker_tag}

echo "Starting publisher container..."
docker run -d \
  --name npa-publisher \
  --restart always \
  --net=host \
  --cap-add NET_ADMIN \
  -e PUBLISHER_TOKEN="${publisher_token}" \
  netskope/publisher:${docker_tag}

echo "=== Publisher Installation Complete ==="
docker ps
```

## Step 6: Compute Instances

Create `gcp-compute.tf`:

```hcl
# =============================================================================
# Service Account
# =============================================================================

resource "google_service_account" "publisher" {
  account_id   = "${var.datacenter_name}-publisher"
  display_name = "Netskope Publisher Service Account"
}

# Minimal permissions for logging
resource "google_project_iam_member" "publisher_logging" {
  project = var.gcp_project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.publisher.email}"
}

resource "google_project_iam_member" "publisher_monitoring" {
  project = var.gcp_project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.publisher.email}"
}

# =============================================================================
# Primary Publisher Instance
# =============================================================================

resource "google_compute_instance" "primary" {
  name         = "${var.datacenter_name}-publisher-primary"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  tags = ["npa-publisher"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.publisher.id
    # No external IP - uses Cloud NAT
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup-script.sh.tpl", {
    publisher_token = netskope_npa_publisher_token.primary.token
    docker_tag      = local.publisher_tag
  })

  service_account {
    email  = google_service_account.publisher.email
    scopes = ["cloud-platform"]
  }

  labels = {
    environment = var.environment
    role        = "npa-publisher"
    managed-by  = "terraform"
  }

  # Allow stopping for updates
  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [
      boot_disk[0].initialize_params[0].image
    ]
  }
}

# =============================================================================
# Secondary Publisher Instance (HA)
# =============================================================================

resource "google_compute_instance" "secondary" {
  count = var.deploy_ha ? 1 : 0

  name         = "${var.datacenter_name}-publisher-secondary"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  tags = ["npa-publisher"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.publisher.id
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup-script.sh.tpl", {
    publisher_token = netskope_npa_publisher_token.secondary[0].token
    docker_tag      = local.publisher_tag
  })

  service_account {
    email  = google_service_account.publisher.email
    scopes = ["cloud-platform"]
  }

  labels = {
    environment = var.environment
    role        = "npa-publisher"
    managed-by  = "terraform"
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [
      boot_disk[0].initialize_params[0].image
    ]
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
# GCP Outputs
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = google_compute_network.publisher.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = google_compute_subnetwork.publisher.id
}

output "instance_names" {
  description = "Compute instance names"
  value = {
    primary   = google_compute_instance.primary.name
    secondary = var.deploy_ha ? google_compute_instance.secondary[0].name : null
  }
}

output "instance_private_ips" {
  description = "Instance private IPs"
  value = {
    primary   = google_compute_instance.primary.network_interface[0].network_ip
    secondary = var.deploy_ha ? google_compute_instance.secondary[0].network_interface[0].network_ip : null
  }
}

output "ssh_command_primary" {
  description = "SSH command to connect via IAP"
  value       = "gcloud compute ssh ${google_compute_instance.primary.name} --zone=${var.gcp_zone} --tunnel-through-iap"
}
```

## Step 8: Deploy

Create `terraform.tfvars`:

```hcl
gcp_project     = "my-gcp-project-id"
gcp_region      = "us-west1"
gcp_zone        = "us-west1-a"
environment     = "production"
datacenter_name = "gcp-usw1"
machine_type    = "e2-medium"
deploy_ha       = true
```

Deploy:

```bash
terraform init
terraform plan
terraform apply
```

## Verifying the Deployment

### SSH via Identity-Aware Proxy (IAP)

```bash
# Connect to primary publisher
gcloud compute ssh gcp-usw1-publisher-primary \
  --zone=us-west1-a \
  --tunnel-through-iap

# Check startup script logs
sudo cat /var/log/publisher-startup.log

# Check Docker status
sudo docker ps
sudo docker logs npa-publisher
```

### View Serial Console Output

```bash
gcloud compute instances get-serial-port-output gcp-usw1-publisher-primary \
  --zone=us-west1-a
```

## Cleanup

```bash
terraform destroy
```

## Next Steps

- [Private App Inventory Tutorial](./private-app-inventory.md) - Create applications
- [Policy as Code Tutorial](./policy-as-code.md) - Create access rules
- [Publisher AWS Tutorial](./publisher-aws.md) - Deploy in AWS
- [Publisher Azure Tutorial](./publisher-azure.md) - Deploy in Azure
