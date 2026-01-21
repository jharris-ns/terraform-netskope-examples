# Netskope Terraform Examples & Guides

Learn how to manage Netskope Private Access (NPA) using Terraform with hands-on tutorials and working examples.

## Who is this for?

- **Netskope administrators** who want to manage NPA using Infrastructure as Code
- **Platform engineers** deploying publishers in AWS, Azure, or GCP
- **Security teams** implementing policy-as-code for access controls

**New to Terraform?** Start with [Terraform Basics](./getting-started/terraform-basics.md).

## Contents

### Getting Started

| Guide | Description |
|-------|-------------|
| [Terraform Basics](./getting-started/terraform-basics.md) | What is Terraform? Key concepts for beginners |
| [Quick Start](./getting-started/quick-start.md) | Create your first private app in 10 minutes |
| [Installation](./getting-started/installation.md) | Provider setup and authentication |

### Tutorials

| Tutorial | Description | Level |
|----------|-------------|-------|
| [Private App Inventory](./tutorials/private-app-inventory.md) | Manage apps at scale with variables and loops | Intermediate |
| [Publisher on AWS](./tutorials/publisher-aws.md) | Deploy publishers in AWS with VPC and NAT Gateway | Intermediate |
| [Publisher on Azure](./tutorials/publisher-azure.md) | Deploy publishers in Azure | Intermediate |
| [Publisher on GCP](./tutorials/publisher-gcp.md) | Deploy publishers in Google Cloud | Intermediate |
| [Policy as Code](./tutorials/policy-as-code.md) | Manage NPA access rules with Terraform | Advanced |

### Guides

| Guide | Description |
|-------|-------------|
| [Best Practices](./guides/best-practices.md) | Project structure, naming, state management |
| [CI/CD Integration](./guides/ci-cd-integration.md) | GitHub Actions, GitLab CI workflows |

### Working Examples

| Example | Description |
|---------|-------------|
| [examples/use-cases/](./examples/use-cases/) | Complete scenarios: browser apps, client apps, full deployments |
| [examples/cloud-deployments/](./examples/cloud-deployments/) | Tested Terraform configs for AWS, Azure, GCP |

## Prerequisites

- Netskope tenant with REST API v2 access
- Terraform 1.0 or later
- For cloud tutorials: AWS/Azure/GCP account with appropriate permissions

## Quick Links

- [Netskope Terraform Provider](https://registry.terraform.io/providers/netskope/netskope/latest) - Terraform Registry
- [Provider Repository](https://github.com/netskope/terraform-provider-netskope) - Source code and API reference
- [Netskope Documentation](https://docs.netskope.com) - Product documentation

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before submitting PRs.

## License

[Apache 2.0](./LICENSE)