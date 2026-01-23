# Project Structure

This document describes the organization of the Terraform Netskope Examples repository.

## Directory Layout

```
terraform-netskope-examples/
├── README.md                           # Main entry point and navigation
├── PROJECT_STRUCTURE.md                # This file
├── CONTRIBUTING.md                     # Contribution guidelines
├── LICENSE                             # Apache 2.0 License
│
├── examples/                           # Runnable Terraform configurations
│   ├── README.md                       # Example index with difficulty levels
│   ├── .gitignore                      # Ignore tfstate, .terraform, tfvars
│   │
│   ├── browser-app/                    # Simple - browser-accessible app
│   │   ├── README.md
│   │   └── main.tf
│   │
│   ├── client-app/                     # Simple - SSH, RDP, database access
│   │   ├── README.md
│   │   └── main.tf
│   │
│   ├── publisher-management/           # Simple - publisher lifecycle
│   │   ├── README.md
│   │   └── main.tf
│   │
│   ├── private-app-inventory/          # Intermediate - manage apps at scale
│   │   ├── README.md
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── data.tf
│   │   ├── apps-*.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── publisher-aws/                  # Intermediate - AWS deployment
│   │   ├── README.md
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── aws.tf
│   │   ├── netskope.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── policy-as-code/                 # Intermediate - access policies
│   │   ├── README.md
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── data.tf
│   │   ├── rules-*.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   └── full-deployment/                # Advanced - complete NPA setup
│       ├── README.md
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
│
├── getting-started/                    # Beginner-focused documentation
│   ├── terraform-basics.md             # Terraform concepts and patterns
│   └── quick-start.md                  # First deployment guide
│
└── guides/                             # Reference documentation
    └── best-practices.md               # Project structure and conventions
```

## Content Types

### Examples (`examples/`)

**Purpose**: Ready-to-deploy Terraform configurations with comprehensive documentation.

**Structure**: Each subdirectory is a complete Terraform project:
- Simple examples: Single `main.tf` file
- Intermediate/Advanced examples: Split into `main.tf`, `variables.tf`, `outputs.tf`, etc.
- Every example has a `README.md` with full documentation including:
  - Quick start instructions
  - What it creates
  - How it works (pattern explanations)
  - Common mistakes
  - Example tfvars

**Difficulty Levels**:
- **Simple**: Single file, minimal configuration
- **Intermediate**: Multiple files, uses patterns like for_each, locals
- **Advanced**: Complex multi-resource deployments

**Usage**:
1. Navigate to an example directory
2. Copy `terraform.tfvars.example` to `terraform.tfvars` (if present)
3. Run `terraform init && terraform apply`

### Getting Started (`getting-started/`)

**Purpose**: Onboarding documentation for new users.

- `terraform-basics.md` - Terraform concepts for beginners, includes **Patterns Used in Our Examples** section documenting common patterns
- `quick-start.md` - Step-by-step first deployment guide

### Guides (`guides/`)

**Purpose**: Reference documentation for best practices and operational guidance.

## File Naming Conventions

- **Markdown files**: kebab-case (e.g., `terraform-basics.md`)
- **Terraform files**: Descriptive names (e.g., `apps-web.tf`, `rules-deny.tf`)
- **Directories**: kebab-case (e.g., `private-app-inventory/`)

## Adding New Content

### Adding a New Example

1. Create directory under `examples/`
2. Add `README.md` with:
   - Quick start instructions
   - What it creates
   - How it works (reference patterns from terraform-basics.md)
   - Common mistakes table
   - Example terraform.tfvars
3. Add Terraform files
4. For intermediate/advanced examples, add `terraform.tfvars.example`
5. Update `examples/README.md` example table with difficulty level
6. Update root `README.md` if appropriate