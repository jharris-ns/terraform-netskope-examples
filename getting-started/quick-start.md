# Getting Started with the Netskope Terraform Provider

**Prerequisites:** Basic command line familiarity. New to Terraform? Read [Terraform Basics](./terraform-basics.md) first.

**What you'll learn:**
- How to configure the Netskope provider
- How to create your first private application
- How to verify resources in the Netskope console

**Time to complete:** 15-20 minutes

---

This guide walks you through setting up the Netskope Terraform provider and creating your first private application resource.

## Prerequisites

Before you begin, ensure you have:

1. **Netskope Tenant** - An active Netskope tenant with administrative access
2. **API Access** - REST API v2 enabled on your tenant
3. **Terraform** - Version 1.0 or later installed ([install guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli))
4. **Publisher** - At least one NPA publisher deployed and connected (required for private apps)

## Step 1: Create an API Key

1. Log in to your Netskope tenant admin console
2. Navigate to **Settings** > **Tools** > **REST API v2**
3. Click **New Token**
4. Configure the token:
   - **Token Name**: `terraform-provider` (or your preferred name)
   - **Expiry**: Set based on your security policy
   - **Endpoints**: Select the NPA endpoints you need:
     - `/api/v2/steering/apps/private` - Private applications
     - `/api/v2/infrastructure/publishers` - Publishers
     - `/api/v2/policy/npa` - NPA policies and rules
5. Click **Save**
6. **Copy the API key immediately** - it won't be shown again

## Step 2: Configure Environment Variables

Store your credentials as environment variables (recommended for security):

```bash
# Your Netskope tenant URL (replace 'mytenant' with your actual tenant name)
export NETSKOPE_SERVER_URL="https://mytenant.goskope.com/api/v2"

# Your API key from Step 1
export NETSKOPE_API_KEY="your-api-key-here"
```

Add these to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) for persistence.

> **Common Mistakes**
>
> | Mistake | Wrong | Correct |
> |---------|-------|---------|
> | Missing `/api/v2` in URL | `https://tenant.goskope.com` | `https://tenant.goskope.com/api/v2` |
> | Missing `https://` | `tenant.goskope.com/api/v2` | `https://tenant.goskope.com/api/v2` |
> | Wrong environment variable | `NETSKOPE_API_TOKEN` | `NETSKOPE_API_KEY` |
> | Expired API key | Key created months ago | Create a new key in the console |

## Step 3: Test Your Connection (Optional)

Before creating resources, verify your credentials work with this minimal test:

```bash
mkdir netskope-test
cd netskope-test
```

Create `main.tf`:

```hcl
terraform {
  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
    }
  }
}

provider "netskope" {}

# Just read existing publishers - no changes made
data "netskope_npa_publishers_list" "all" {}

output "publisher_count" {
  value = length(data.netskope_npa_publishers_list.all.data.publishers)
}
```

Run:
```bash
terraform init && terraform apply -auto-approve
```

Expected output:
```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

publisher_count = 2
```

If this works, your credentials are correctly configured. You can delete this test directory and proceed to create real resources.

---

## Step 4: Create Your First Private App

Create a new directory for your Terraform project:

```bash
mkdir netskope-npa
cd netskope-npa
```

Create `main.tf` with the following content:

```hcl
# =============================================================================
# Terraform Configuration
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.3"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================

# The provider reads NETSKOPE_SERVER_URL and NETSKOPE_API_KEY from environment
provider "netskope" {}

# =============================================================================
# Data Sources - Discover Existing Resources
# =============================================================================

# List all publishers to find one to assign to our app
# See: https://registry.terraform.io/providers/netskopeoss/netskope/latest/docs/data-sources/npa_publishers_list
data "netskope_npa_publishers_list" "all" {}

# =============================================================================
# Local Values
# =============================================================================

locals {
  # Get the first available publisher
  # In production, you would select a specific publisher by name or ID
  first_publisher = data.netskope_npa_publishers_list.all.data.publishers[0]
}

# =============================================================================
# Resources
# =============================================================================

# Create a private application
# See: https://registry.terraform.io/providers/netskopeoss/netskope/latest/docs/resources/npa_private_app
resource "netskope_npa_private_app" "my_first_app" {
  # Application identity
  private_app_name     = "my-first-terraform-app"
  private_app_hostname = "app.internal.example.com"
  private_app_protocol = "https"

  # Backend server - where traffic is actually sent
  real_host = "10.0.1.100"

  # Access settings
  clientless_access  = true   # Allow browser access
  is_user_portal_app = true   # Show in user portal
  use_publisher_dns  = true   # Use publisher for DNS resolution

  # Protocol configuration
  protocols = [
    {
      port     = "443"
      protocol = "tcp"
    }
  ]

  # Publisher assignment - required for the app to be reachable
  publishers = [
    {
      publisher_id   = tostring(local.first_publisher.publisher_id)
      publisher_name = local.first_publisher.publisher_name
    }
  ]

  # Tags for organization
  tags = [
    { tag_name = "terraform-managed" },
    { tag_name = "example" }
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "app_id" {
  description = "The ID of the created private app"
  value       = netskope_npa_private_app.my_first_app.private_app_id
}

output "app_url" {
  description = "The browser access URL for the app"
  value       = "https://${netskope_npa_private_app.my_first_app.private_app_hostname}"
}

output "assigned_publisher" {
  description = "The publisher assigned to this app"
  value       = local.first_publisher.publisher_name
}
```

## Step 5: Initialize and Apply

```bash
# Initialize Terraform (downloads the provider)
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding netskope/netskope versions matching ">= 0.3.0"...
- Installing netskope/netskope v0.3.5...
- Installed netskope/netskope v0.3.5 (signed by a HashiCorp partner)

Terraform has been successfully initialized!
```

```bash
# Preview the changes
terraform plan
```

Expected output:
```
data.netskope_npa_publishers_list.all: Reading...
data.netskope_npa_publishers_list.all: Read complete after 1s

Terraform will perform the following actions:

  # netskope_npa_private_app.my_first_app will be created
  + resource "netskope_npa_private_app" "my_first_app" {
      + private_app_name     = "my-first-terraform-app"
      + private_app_hostname = "app.internal.example.com"
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

```bash
# Apply the configuration
terraform apply
```

When prompted, type `yes` to confirm the creation.

Expected output after confirmation:
```
netskope_npa_private_app.my_first_app: Creating...
netskope_npa_private_app.my_first_app: Creation complete after 2s [id=12345]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

app_id = "12345"
app_url = "https://app.internal.example.com"
assigned_publisher = "us-west-dc1-primary"
```

## Step 6: Verify in the Console

1. Log in to your Netskope admin console
2. Navigate to **Settings** > **Security Cloud Platform** > **App Definition** > **Private Apps**
3. You should see `my-first-terraform-app` listed

## Understanding the Configuration

### Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `private_app_name` | Unique name for the application | `"my-web-app"` |
| `private_app_hostname` | Hostname users connect to | `"app.internal.example.com"` |
| `private_app_protocol` | Application protocol | `"https"`, `"ssh"`, `"rdp"` |
| `real_host` | Backend server IP or hostname | `"10.0.1.100"` |
| `publishers` | List of publishers to handle traffic | See example above |
| `protocols` | Port and transport protocol | `[{ port = "443", protocol = "tcp" }]` |

### Access Types

| Setting | Browser Access | Client Required | Use Case |
|---------|---------------|-----------------|----------|
| `clientless_access = true` | Yes | No | Web applications |
| `clientless_access = false` | No | Yes | SSH, RDP, databases |
| Both with `is_user_portal_app = true` | Yes | Optional | Flexible access |

## Next Steps

- **[Private App Inventory](../tutorials/private-app-inventory.md)** - Manage multiple apps at scale
- **[Publisher on AWS](../tutorials/publisher-aws.md)** - Deploy publishers in AWS
- **[Policy as Code](../tutorials/policy-as-code.md)** - Manage access rules with Terraform
- **[API Reference](https://registry.terraform.io/providers/netskopeoss/netskope/latest/docs)** - Full resource and data source documentation

## Common Issues

### "No publishers found"

Your tenant needs at least one deployed publisher. See the [Netskope documentation](https://docs.netskope.com) for publisher deployment.

### "401 Unauthorized"

Verify your API key:
```bash
echo $NETSKOPE_API_KEY  # Should show your key
```

### "Invalid server URL"

Check your tenant URL format:
```bash
echo $NETSKOPE_SERVER_URL  # Should be https://tenant.goskope.com/api/v2
```

## Cleaning Up

To remove the resources created by this guide:

```bash
terraform destroy
```

Type `yes` when prompted to confirm deletion.
