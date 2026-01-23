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

## Patterns Used in Our Examples

These patterns appear throughout the examples in this repository. Each pattern includes a reference to where you can see it in action.

### 1. Selection by Name

Find a specific item from a list by matching an attribute.

```hcl
# Find a publisher by name from the data source list
# Used in: examples/browser-app/main.tf, examples/private-app-inventory/data.tf
primary_publisher = [
  for pub in data.netskope_npa_publishers_list.all.data.publishers :
  pub if pub.publisher_name == var.primary_publisher_name
][0]
```

**How it works:**

This is a for-expression with a filter that returns a single matching item.

**Step 1 - For-expression structure:**
```hcl
[for <item> in <list> : <return_value> if <condition>]
```

**Step 2 - Iterate through all publishers:**
```hcl
for pub in data.netskope_npa_publishers_list.all.data.publishers
```

**Step 3 - Specify what to return (the full publisher object):**
```hcl
: pub
```

**Step 4 - Filter to only matching items:**
```hcl
if pub.publisher_name == var.primary_publisher_name
```

**Step 5 - Extract the single result:**
```hcl
[0]
```
The for-expression returns a list. Since we expect exactly one match, `[0]` gets that item.

**Example:**

Given:
- `var.primary_publisher_name = "us-west-pub"`
- Publishers from data source: `[{publisher_name: "us-east-pub", publisher_id: 1}, {publisher_name: "us-west-pub", publisher_id: 2}]`

Result: `{publisher_name: "us-west-pub", publisher_id: 2}`

This pattern is useful when you know a resource exists and need to find it by a human-readable name rather than an ID.

### 2. Ternary Operator for Optional Values

Choose between two values based on a condition.

```hcl
# Use a specific publisher if provided, otherwise use the first available
# Used in: examples/browser-app/main.tf, examples/client-app/main.tf
publisher = var.publisher_name != null ? (
  [for p in data... : p if p.publisher_name == var.publisher_name][0]
) : data.netskope_npa_publishers_list.all.data.publishers[0]
```

**How it works:**

This combines two patterns: a ternary operator (outer) and a for-expression (inner).

**Outer expression - Ternary operator:**
```hcl
condition ? value_if_true : value_if_false
```
- **Condition:** `var.publisher_name != null` - was a publisher name provided?
- **If true:** Execute the for-expression to find the matching publisher
- **If false:** Use the first publisher in the list as a default

**Inner expression - For-expression with filter (when condition is true):**
```hcl
[for p in data... : p if p.publisher_name == var.publisher_name][0]
```
- `for p in data...` - iterate through all publishers
- `: p` - return the full publisher object
- `if p.publisher_name == var.publisher_name` - only include publishers where the name matches
- `[0]` - get the first (and should be only) match from the filtered list

**Example:**

Given:
- `var.publisher_name = "us-west-pub"` (user provided a name)
- Publishers: `[{name: "us-east-pub"}, {name: "us-west-pub"}]`

Result: The `us-west-pub` publisher object is returned.

If `var.publisher_name = null` (user didn't provide a name), the first publisher (`us-east-pub`) is returned as a default.

### 3. Building Object Lists

Create lists of objects with specific keys required by the API.

```hcl
# Private apps require publishers as objects with specific keys
# Used in: examples/private-app-inventory/data.tf
app_publishers = [
  {
    publisher_id   = tostring(local.primary_publisher.publisher_id)
    publisher_name = local.primary_publisher.publisher_name
  }
]
```

**How it works:**

Many APIs require data in a specific structure. The Netskope API expects publishers as a list of objects with exact key names:
```hcl
publishers = [
  { publisher_id = "123", publisher_name = "pub-1" },
  { publisher_id = "456", publisher_name = "pub-2" }
]
```

This pattern builds that structure from data you've looked up elsewhere. Note the use of `tostring()` - the API expects `publisher_id` as a string, but the data source returns it as a number.

### 4. Tag Formatting

Convert a simple list of strings to the object format required by the API.

```hcl
# Convert ["tag1", "tag2"] to [{ tag_name = "tag1" }, { tag_name = "tag2" }]
# Used in: examples/private-app-inventory/data.tf
common_tag_objects = [
  for tag in var.common_tags : { tag_name = tag }
]
```

**How it works:**

The Netskope API expects tags in this format:
```hcl
tags = [{ tag_name = "production" }, { tag_name = "web-tier" }]
```

But it's easier to define variables as simple strings:
```hcl
common_tags = ["production", "web-tier"]
```

This for-expression transforms each string into the required object format:
- `for tag in var.common_tags` - iterate through each string
- `: { tag_name = tag }` - create an object with the `tag_name` key

### 5. Lookup Maps

Translate user-friendly values to API-required values.

```hcl
# Map friendly names to protocol values
# Used in: examples/private-app-inventory/apps-infrastructure.tf
locals {
  infra_protocols = {
    ssh = "ssh"
    rdp = "rdp"
    vnc = "vnc"
  }
}

# Usage with lookup(map, key, default)
private_app_protocol = lookup(local.infra_protocols, each.value.app_type, "tcp")
```

**How it works:**

`lookup(map, key, default)` searches a map for a key and returns its value, or a default if not found:
- `lookup(local.infra_protocols, "ssh", "tcp")` returns `"ssh"`
- `lookup(local.infra_protocols, "unknown", "tcp")` returns `"tcp"` (the default)

This pattern is useful when:
- Users provide friendly names that need translation
- You want safe defaults for unexpected values
- You're mapping between different naming conventions

### 6. Conditional Count

Create a resource only when a condition is met.

```hcl
# Only create the rule if there are matching apps
# Used in: examples/policy-as-code/rules-teams.tf
resource "netskope_npa_rules" "developer_web_access" {
  count = length(local.web_apps) > 0 ? 1 : 0
  # ...
}

# Reference with [0] when using count
rule_id = netskope_npa_rules.developer_web_access[0].id
```

**How it works:**

The `count` meta-argument controls how many instances Terraform creates:
- `count = 0` - resource is not created
- `count = 1` - one instance is created

The expression `length(local.web_apps) > 0 ? 1 : 0` means:
- If `local.web_apps` has items → create the resource
- If `local.web_apps` is empty → skip the resource

**Important:** When using `count`, you must reference the resource with an index, even for single instances:
```hcl
# Correct
netskope_npa_rules.developer_web_access[0].id

# Wrong - will error
netskope_npa_rules.developer_web_access.id
```

### 7. for_each with Maps

Create multiple resources from a map variable.

```hcl
# Create an app for each entry in the map
# Used in: examples/private-app-inventory/apps-web.tf
resource "netskope_npa_private_app" "web" {
  for_each = var.web_apps

  private_app_name     = "${var.environment}-${each.key}"
  private_app_hostname = each.value.hostname
  real_host            = each.value.real_host
  # ...
}
```

**How it works:**

Given this variable:
```hcl
web_apps = {
  jira       = { hostname = "jira.internal.com", ... }
  confluence = { hostname = "wiki.internal.com", ... }
}
```

Terraform creates two resources with meaningful addresses:
- `netskope_npa_private_app.web["jira"]`
- `netskope_npa_private_app.web["confluence"]`

Inside the resource block:
- `each.key` - the map key (e.g., `"jira"`)
- `each.value` - the full object for that key
- `each.value.hostname` - a specific attribute

**Why for_each over count?** With `for_each`, removing an item only destroys that specific resource. With `count`, removing an item shifts all indexes, potentially recreating unrelated resources.

### 8. Concat for Merging Lists

Combine multiple lists into one.

```hcl
# Merge common tags with resource-specific tags
# Used in: examples/private-app-inventory/apps-web.tf
tags = concat(
  local.common_tag_objects,
  local.env_tag,
  [{ tag_name = "web-tier" }],
  [for tag in each.value.tags : { tag_name = tag }]
)
```

**How it works:**

`concat()` joins multiple lists into a single list:
```hcl
concat(["a", "b"], ["c"], ["d", "e"])
# Result: ["a", "b", "c", "d", "e"]
```

In the example, we combine:
1. `local.common_tag_objects` - tags for all resources
2. `local.env_tag` - environment tag
3. `[{ tag_name = "web-tier" }]` - tier-specific tag
4. Additional tags from the variable

**Note:** Single items must be wrapped in brackets `[]` because `concat()` requires lists.

### 9. Coalesce for Null Handling

Provide a default value when something might be null.

```hcl
# Use empty list if tags is null
# Used in: examples/policy-as-code/data.tf
for tag in coalesce(app.tags, []) :
  tag if contains(var.web_app_tags, tag.tag_name)
```

**How it works:**

`coalesce()` returns the first non-null value from its arguments:
```hcl
coalesce(null, "default")     # Returns: "default"
coalesce("value", "default")  # Returns: "value"
coalesce(null, [])            # Returns: []
```

This is essential when data sources return `null` instead of empty lists. Without `coalesce()`, iterating over `null` causes an error:
```hcl
# Error if app.tags is null
for tag in app.tags : ...

# Safe - converts null to empty list
for tag in coalesce(app.tags, []) : ...
```

### 10. String Interpolation

Embed variables or expressions inside strings.

```hcl
# Create environment-prefixed names
# Used throughout examples
private_app_name = "${var.environment}-${each.key}"
```

**How it works:**

Use `${}` to embed expressions inside strings:
```hcl
name = "${var.environment}-${var.app_name}"
# If environment="prod" and app_name="web", result is "prod-web"
```

You can embed any expression:
```hcl
description = "Created on ${timestamp()}"
url         = "https://${var.hostname}:${var.port}"
```

### 11. Type Conversion with tostring/tonumber

Convert between types when APIs require specific types.

```hcl
# API expects string, but publisher_id is a number
publisher_id = tostring(local.primary_publisher.publisher_id)

# API expects number for rule ordering
rule_id = tonumber(netskope_npa_rules.deny_blocked_users.id)
```

**How it works:**

Terraform is strictly typed. When an API returns a number but expects a string (or vice versa), use these functions:
- `tostring(123)` returns `"123"`
- `tonumber("123")` returns `123`

Common scenarios:
- IDs returned as numbers but needed as strings in other resources
- String IDs that need to be numbers for arithmetic or ordering
- API responses that don't match expected types

### 12. Filtering Lists by Nested Attributes

Filter a list based on a nested attribute (like tags). This is an advanced pattern - for background, see the official [Terraform For Expressions](https://developer.hashicorp.com/terraform/language/expressions/for) documentation.

```hcl
# Get app names where any tag matches our target tags
# Used in: examples/policy-as-code/data.tf
web_apps = [
  for app in data.netskope_npa_private_apps_list.all.private_apps :
  app.private_app_name
  if length([
    for tag in coalesce(app.tags, []) :
    tag if contains(var.web_app_tags, tag.tag_name)
  ]) > 0
]
```

**How it works:**

This nested for-expression filters apps based on their tags. Breaking it down step by step:

**Step 1 - Outer loop structure:**
```hcl
[for app in <list> : <return_value> if <condition>]
```

**Step 2 - Iterate through all apps:**
```hcl
for app in data.netskope_npa_private_apps_list.all.private_apps
```

**Step 3 - Specify what to return (the app name, not the full object):**
```hcl
app.private_app_name
```

**Step 4 - Filter with a condition that uses an inner for-expression:**
```hcl
if length([...]) > 0
```
Only include this app if the inner expression returns at least one item.

**Step 5 - Inner for-expression checks each tag:**
```hcl
for tag in coalesce(app.tags, []) : tag if contains(var.web_app_tags, tag.tag_name)
```
- `coalesce(app.tags, [])` - safely handle null (use empty list if tags is null)
- `contains(var.web_app_tags, tag.tag_name)` - check if this tag is in our target list

**Example:**

Given:
- Apps: `[{name: "app1", tags: [{tag_name: "web"}]}, {name: "app2", tags: [{tag_name: "db"}]}]`
- Target tags: `["web"]`

Result: `["app1"]` - only apps with a matching tag are included

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
