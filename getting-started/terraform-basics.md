# Terraform Basics for Netskope Users

**Prerequisites:** None - this guide assumes no prior Terraform knowledge

**What you'll learn:**
- What Terraform is and why use it
- Key concepts: resources, data sources, variables, outputs, state
- The Terraform workflow: init, plan, apply, destroy
- Basic HCL syntax

---

## What is Terraform?

Terraform is an **Infrastructure as Code (IaC)** tool that lets you define and manage infrastructure using configuration files instead of clicking through a web console.

Instead of manually creating private apps in the Netskope console, you write configuration files that describe what you want. Terraform then creates, updates, or deletes resources to match your configuration.

### Benefits for Netskope Administrators

| Manual (Console) | Terraform |
|------------------|-----------|
| Click through UI for each app | Define apps in text files |
| No audit trail of changes | Full version control with git |
| Hard to replicate across environments | Copy configs between prod/staging/dev |
| Prone to inconsistencies | Guaranteed consistency |
| No review process | Pull request reviews before changes |

---

## Key Concepts

### 1. Providers

A **provider** is a plugin that connects Terraform to a specific service. The Netskope provider connects Terraform to your Netskope tenant.

```hcl
# Tell Terraform to use the Netskope provider
terraform {
  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.3"
    }
  }
}

# Configure the provider (reads credentials from environment variables)
provider "netskope" {}
```

### 2. Resources

A **resource** is something Terraform creates and manages. When you define a resource, Terraform will create it in Netskope.

```hcl
# This creates a private app in Netskope
resource "netskope_npa_private_app" "my_app" {
  private_app_name     = "my-web-app"
  private_app_hostname = "app.internal.company.com"
  # ... more settings
}
```

The format is:
```text
resource "<provider>_<resource_type>" "<your_name>" {
  # settings
}
```

- `netskope_npa_private_app` - the resource type (from the provider)
- `my_app` - a name YOU choose (used to reference this resource elsewhere)

### 3. Data Sources

A **data source** reads existing information from Netskope. Unlike resources, data sources don't create anything - they just fetch data.

```hcl
# Read the list of existing publishers from Netskope
data "netskope_npa_publishers_list" "all" {}

# Now you can use: data.netskope_npa_publishers_list.all.data.publishers
```

Use data sources to:
- Find IDs of existing resources
- Look up publishers to assign to apps
- Discover what already exists in your tenant

### 4. Variables

**Variables** are inputs to your configuration. They let you reuse the same config with different values.

```hcl
# Define a variable
variable "app_name" {
  description = "Name of the application"
  type        = string
}

# Use it with var.<name>
resource "netskope_npa_private_app" "my_app" {
  private_app_name = var.app_name
}
```

Set variable values in `terraform.tfvars`:
```hcl
app_name = "production-web-app"
```

### 5. Outputs

**Outputs** display values after Terraform runs. Useful for seeing IDs, URLs, or other computed values.

```hcl
output "app_id" {
  description = "The ID of the created app"
  value       = netskope_npa_private_app.my_app.private_app_id
}
```

After `terraform apply`, you'll see:
```
Outputs:

app_id = "12345"
```

### 6. State

Terraform keeps track of what it has created in a **state file** (`terraform.tfstate`). This file maps your configuration to real resources in Netskope.

**Important:**
- Never edit the state file manually
- Don't commit `terraform.tfstate` to git (it may contain sensitive data)
- For teams, use remote state storage (covered in best practices)

---

## The Terraform Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Terraform Workflow                          │
│                                                                     │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    │
│   │  Write   │    │   Init   │    │   Plan   │    │  Apply   │    │
│   │  Config  │ -> │          │ -> │          │ -> │          │    │
│   │ (.tf)    │    │ Download │    │ Preview  │    │ Execute  │    │
│   │          │    │ Provider │    │ Changes  │    │ Changes  │    │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘    │
│                                                                     │
│                              Optional:                              │
│                         ┌──────────────┐                           │
│                         │   Destroy    │                           │
│                         │ Remove All   │                           │
│                         └──────────────┘                           │
└─────────────────────────────────────────────────────────────────────┘
```

### Step 1: Write Configuration

Create `.tf` files that describe your desired state:

```hcl
# main.tf
resource "netskope_npa_private_app" "web" {
  private_app_name = "my-web-app"
  # ...
}
```

### Step 2: Initialize (`terraform init`)

Downloads the provider plugins. Run once when starting a new project or after adding providers.

```bash
terraform init
```

### Step 3: Plan (`terraform plan`)

Shows what Terraform will do **without making changes**. Always review the plan before applying.

```bash
terraform plan
```

Output shows:
- `+` resources to be created
- `-` resources to be destroyed
- `~` resources to be modified

### Step 4: Apply (`terraform apply`)

Executes the changes. Terraform will show the plan and ask for confirmation.

```bash
terraform apply
```

Type `yes` to confirm.

### Step 5: Destroy (`terraform destroy`)

Removes all resources managed by this configuration. Use carefully!

```bash
terraform destroy
```

---

## HCL Syntax Basics

HCL (HashiCorp Configuration Language) is the syntax used in `.tf` files.

### Blocks

Configuration is organized in **blocks**:

```hcl
block_type "label1" "label2" {
  argument1 = "value"
  argument2 = 123

  nested_block {
    nested_arg = "nested value"
  }
}
```

### Data Types

| Type | Example | Notes |
|------|---------|-------|
| String | `"hello"` | Always use double quotes |
| Number | `42` | No quotes |
| Boolean | `true` / `false` | No quotes |
| List | `["a", "b", "c"]` | Square brackets |
| Map | `{ key = "value" }` | Curly braces |

### Common Patterns

**Referencing other resources:**
```hcl
# Reference: <resource_type>.<name>.<attribute>
publisher_id = netskope_npa_publisher.my_pub.publisher_id
```

**Referencing data sources:**
```hcl
# Reference: data.<data_source_type>.<name>.<attribute>
publishers = data.netskope_npa_publishers_list.all.data.publishers
```

**Referencing variables:**
```hcl
# Reference: var.<variable_name>
app_name = var.environment
```

**String interpolation:**
```hcl
# Use ${} inside strings
name = "${var.environment}-web-app"
```

**Lists of objects:**
```hcl
protocols = [
  {
    port     = "443"
    protocol = "tcp"
  }
]
```

---

## File Organization

A typical Terraform project:

```
my-project/
├── main.tf           # Provider config, main resources
├── variables.tf      # Variable definitions
├── outputs.tf        # Output definitions
├── terraform.tfvars  # Variable values (don't commit!)
└── .gitignore        # Ignore state and tfvars
```

**`.gitignore` for Terraform:**
```gitignore
# State files (may contain sensitive data)
*.tfstate
*.tfstate.*

# Variable files (may contain secrets)
*.tfvars
*.auto.tfvars

# Terraform directories
.terraform/
.terraform.lock.hcl
```

---

## Common Commands Reference

| Command | Purpose |
|---------|---------|
| `terraform init` | Initialize project, download providers |
| `terraform plan` | Preview changes |
| `terraform apply` | Apply changes |
| `terraform destroy` | Remove all resources |
| `terraform fmt` | Format code consistently |
| `terraform validate` | Check syntax |
| `terraform output` | Show output values |
| `terraform state list` | List resources in state |

---

## Next Steps

Now that you understand the basics:

1. **[Quick Start Guide](./quick-start.md)** - Set up the Netskope provider and create your first resource
2. **[Best Practices](../guides/best-practices.md)** - Project structure, naming conventions, and security

---

## Glossary

| Term | Definition |
|------|------------|
| **HCL** | HashiCorp Configuration Language - the syntax for `.tf` files |
| **Provider** | Plugin that connects Terraform to a service (e.g., Netskope, AWS) |
| **Resource** | Something Terraform creates and manages |
| **Data Source** | A read-only query to fetch existing data |
| **State** | Terraform's record of what resources it manages |
| **Plan** | Preview of what Terraform will do |
| **Apply** | Execute the planned changes |
| **Destroy** | Remove all managed resources |
