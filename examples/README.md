# Netskope Terraform Examples

Ready-to-deploy Terraform configurations for Netskope services, organized by product area.

## Prerequisites

- **Terraform** >= 1.0
- **Netskope tenant** with REST API v2 access enabled
- **API credentials** from Settings > Tools > REST API v2
- Product-specific licenses (NPA, DNS Security, IPSec) as noted per topic

## Quick Start

### 1. Set Credentials

```bash
export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"
```

### 2. Choose an Example

```bash
cd npa/browser-app   # or any other example directory
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Cleanup

```bash
terraform destroy
```

## Topics

| Topic | Description | Examples |
|-------|-------------|----------|
| [npa/](./npa/) | Netskope Private Access — apps, publishers, policies, RBAC | 11 examples |
| [dnsprofiles/](./dnsprofiles/) | DNS Security — profiles, categories, tunneling detection | 3 examples |
| [ipsec/](./ipsec/) | IPSec tunnels — traffic steering, AWS Transit Gateway | 2 examples |
| [web-policy/](./web-policy/) | Real-time Protection — custom categories, service objects | 2 examples |

### NPA (Netskope Private Access)

| Example | Difficulty | Description |
|---------|------------|-------------|
| [npa/browser-app/](./npa/browser-app/) | Simple | Browser-accessible private application |
| [npa/client-app/](./npa/client-app/) | Simple | SSH, RDP, and database access via NPA client |
| [npa/publisher-management/](./npa/publisher-management/) | Simple | Publisher lifecycle and upgrades |
| [npa/local-broker-management/](./npa/local-broker-management/) | Simple | Local broker configuration and tokens |
| [npa/private-app-inventory/](./npa/private-app-inventory/) | Intermediate | Manage multiple apps at scale with variables |
| [npa/publisher-aws/](./npa/publisher-aws/) | Intermediate | Deploy NPA publisher in AWS with VPC |
| [npa/policy-as-code/](./npa/policy-as-code/) | Intermediate | Access policies with deny rules and ordering |
| [npa/device-classification/](./npa/device-classification/) | Simple | Device posture enforcement via classification tags |
| [npa/rbac-labels/](./npa/rbac-labels/) | Simple | Label-based access control for NPA resources |
| [npa/rbac-roles/](./npa/rbac-roles/) | Simple | Admin role definitions with API group permissions |
| [npa/full-deployment/](./npa/full-deployment/) | Advanced | End-to-end NPA setup: publishers, apps, and policies |

### DNS Security

| Example | Difficulty | Description |
|---------|------------|-------------|
| [dnsprofiles/basic-profile/](./dnsprofiles/basic-profile/) | Simple | DNS profile with domain allow and block lists |
| [dnsprofiles/security-categories/](./dnsprofiles/security-categories/) | Intermediate | Category-based blocking and sinkholing |
| [dnsprofiles/full-deployment/](./dnsprofiles/full-deployment/) | Advanced | Complete DNS setup with tunneling, custom DNS, inheritance |

### IPSec

| Example | Difficulty | Description |
|---------|------------|-------------|
| [ipsec/vpn/](./ipsec/vpn/) | Intermediate | IPSec tunnel steering configuration |
| [ipsec/aws-transitgateway-vpn/](./ipsec/aws-transitgateway-vpn/) | Advanced | AWS Transit Gateway + Netskope IPSec integration |

### Web Policy (Real-time Protection)

| Example | Difficulty | Description |
|---------|------------|-------------|
| [web-policy/custom-categories/](./web-policy/custom-categories/) | Simple | Combine URL lists and destination profiles into policy objects |
| [web-policy/service-objects/](./web-policy/service-objects/) | Simple | Named port/protocol profiles for firewall rules |

## Configuration

Most examples with variables support a `terraform.tfvars` file:

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
terraform apply
```

## Further Reading

Users with limited Terraform experience should first review [Patterns Used in Our Examples](../getting-started/terraform-basics.md#patterns-used-in-our-examples).

- [Terraform Basics](../getting-started/terraform-basics.md) - New to Terraform?
- [Best Practices](../guides/best-practices.md) - Project structure and patterns
- [Provider Documentation](https://registry.terraform.io/providers/netskopeoss/netskope/latest/docs)
