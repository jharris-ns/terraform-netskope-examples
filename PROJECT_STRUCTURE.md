# Project Structure

This document describes the organization of the Terraform Netskope Examples repository.

## Directory Layout

```
terraform-netskope-examples/
├── README.md                           # Main entry point and navigation
├── PROJECT_STRUCTURE.md                # This file
│
├── code/                               # Runnable Terraform configurations
│   ├── README.md                       # Deployment instructions for all examples
│   ├── .gitignore                      # Ignore tfstate, .terraform, tfvars
│   │
│   ├── browser-app/                    # Simple example
│   │   ├── README.md
│   │   └── main.tf
│   │
│   ├── client-app/                     # Simple example
│   │   ├── README.md
│   │   └── main.tf
│   │
│   ├── policy-as-code/                 # Modular example
│   │   ├── README.md
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── data.tf
│   │   ├── rules-*.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── private-app-inventory/          # Modular example
│   │   ├── README.md
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── data.tf
│   │   ├── apps-*.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── publisher-aws/                  # Modular example
│   │   ├── README.md
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── aws.tf
│   │   ├── netskope.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── publisher-management/           # Simple example
│   │   ├── README.md
│   │   └── main.tf
│   │
│   └── full-deployment/                # Modular example
│       ├── README.md
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
│
├── tutorials/                          # In-depth tutorial guides
│   ├── policy-as-code.md               # → code/policy-as-code/
│   ├── private-app-inventory.md        # → code/private-app-inventory/
│   └── publisher-aws.md                # → code/publisher-aws/
│
├── getting-started/                    # Beginner-focused documentation
│   ├── terraform-basics.md
│   └── quick-start.md
│
└── guides/                             # Reference documentation
    └── best-practices.md
```

## Content Types

### Code (`code/`)

**Purpose**: Ready-to-deploy Terraform configurations.

**Structure**: Each subdirectory is a complete Terraform project:
- Simple examples: Single `main.tf` file
- Modular examples: Split into `main.tf`, `variables.tf`, `outputs.tf`, etc.
- Every example has a `README.md` explaining what it does

**Usage**:
1. Navigate to an example directory
2. Copy `terraform.tfvars.example` to `terraform.tfvars` (if present)
3. Run `terraform init && terraform apply`

### Tutorials (`tutorials/`)

**Purpose**: Step-by-step learning guides with explanations and embedded code snippets.

**Format**: Markdown files with:
- Conceptual explanations
- Architecture diagrams
- Code snippets with commentary
- Common mistakes and solutions

**Relationship to Code**: Each tutorial links to its corresponding `code/` directory. Users can:
- Read the tutorial to understand concepts
- Deploy the actual code from `code/`

### Getting Started (`getting-started/`)

**Purpose**: Onboarding documentation for new users.

### Guides (`guides/`)

**Purpose**: Reference documentation for best practices and operational guidance.

## Tutorial ↔ Code Mapping

| Tutorial | Code Directory |
|----------|----------------|
| `tutorials/policy-as-code.md` | `code/policy-as-code/` |
| `tutorials/private-app-inventory.md` | `code/private-app-inventory/` |
| `tutorials/publisher-aws.md` | `code/publisher-aws/` |

## File Naming Conventions

- **Markdown files**: kebab-case (e.g., `policy-as-code.md`)
- **Terraform files**: Descriptive names (e.g., `apps-web.tf`, `rules-deny.tf`)
- **Directories**: kebab-case (e.g., `private-app-inventory/`)

## Adding New Content

### Adding a New Example

1. Create directory under `code/`
2. Add `README.md` with description, prerequisites, and usage
3. Add Terraform files
4. For modular examples, add `terraform.tfvars.example`
5. Update `code/README.md` example table
6. Update root `README.md` if appropriate

### Adding a New Tutorial

1. Create `tutorials/<topic>.md`
2. Create corresponding `code/<topic>/` directory
3. Link tutorial to code directory
4. Update root `README.md` tutorials table
