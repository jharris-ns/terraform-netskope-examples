# AWS Transit Gateway + Netskope IPSec Integration

Connect AWS workloads to Netskope's Security Cloud Platform by creating Site-to-Site VPN connections from an AWS Transit Gateway to Netskope IPSec POPs.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                         AWS                              │
│                                                          │
│  ┌─────────┐    ┌─────────────────┐    ┌──────────────┐ │
│  │  VPC A  │───►│                 │    │  Customer GW │ │
│  └─────────┘    │ Transit Gateway │───►│  (Netskope)  │─┼──► Netskope iad2 (Dulles)
│  ┌─────────┐    │                 │    └──────────────┘ │
│  │  VPC B  │───►│                 │    ┌──────────────┐ │
│  └─────────┘    │                 │───►│  Customer GW │─┼──► Netskope atl1 (Atlanta)
│                 └─────────────────┘    │  (Netskope)  │ │
│                                        └──────────────┘ │
└──────────────────────────────────────────────────────────┘
```

Each AWS VPN connection creates 2 tunnels. This example creates 2 VPN connections (primary + backup) for a total of **4 IPSec tunnels** to Netskope, providing full redundancy.

## Prerequisites

- Netskope tenant with IPSec/GRE license
- REST API v2 token
- AWS account with permissions to create VPN connections, Customer Gateways, and Transit Gateways
- Terraform installed

## Files

| File | Description |
|------|-------------|
| `aws_tgw_integration.tf` | Main configuration — VPN connections, Customer Gateways, Netskope tunnels |
| `tgw.tf` | Test Transit Gateway (remove if using an existing TGW) |
| `example.tfvars` | Example variable values (copy to terraform.tfvars) |

## Getting Started

### 1. Configure credentials

Netskope — set environment variables:

```bash
export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-v2-token"
```

AWS — ensure your profile is logged in:

```bash
aws sso login --profile your-aws-profile
```

### 2. Configure variables

```bash
cp example.tfvars terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Look up available POPs

```bash
terraform init
terraform plan
```

The plan output includes the full list of Netskope IPSec POPs. Choose POPs geographically close to your AWS region. Common mappings:

| AWS Region | Suggested POPs |
|------------|----------------|
| us-east-1 (Virginia) | `iad2`, `iad4` |
| us-east-2 (Ohio) | `ord1`, `ord2` (Chicago) |
| us-west-1 (N. California) | `sfo1` |
| us-west-2 (Oregon) | `sea2` |
| eu-west-1 (Ireland) | `lon1`, `lon2` |
| eu-central-1 (Frankfurt) | `fra1` |
| ap-southeast-1 (Singapore) | `sin1`, `sin3` |
| ap-northeast-1 (Tokyo) | `nrt2`, `nrt3` |

### 4. Apply

```bash
terraform apply
```

### 5. Using an existing Transit Gateway

If you already have a Transit Gateway, delete `tgw.tf` and update `aws_tgw_integration.tf` to reference your TGW:

1. Remove `tgw.tf`
2. Add a variable for your TGW ID:
   ```hcl
   variable "transit_gateway_id" {
     type = string
   }
   ```
3. Replace `aws_ec2_transit_gateway.test.id` with `var.transit_gateway_id` in the VPN connection resources

## Variables

### Required

| Variable | Description |
|----------|-------------|
| `pre_shared_key` | IPSec PSK shared between AWS and Netskope |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region for deployment |
| `aws_profile` | `null` | AWS CLI profile name |
| `tunnel_name_prefix` | `AWS-TGW` | Prefix for all tunnel/resource names |
| `primary_pop_name` | `iad2` | Primary Netskope POP short code |
| `backup_pop_name` | `atl1` | Backup Netskope POP short code |
| `destination_cidrs` | `["0.0.0.0/0"]` | CIDRs to route through Netskope |

## Resources Created

### AWS

| Resource | Count | Description |
|----------|-------|-------------|
| Transit Gateway | 1 | Test TGW (from `tgw.tf`) |
| Customer Gateway | 2 | Netskope POP gateway IPs as AWS Customer Gateways |
| VPN Connection | 2 | Site-to-Site VPN (2 tunnels each) attached to Transit Gateway |

### Netskope

| Resource | Count | Description |
|----------|-------|-------------|
| IPSec Tunnel | 4 | One per AWS VPN tunnel (2 primary + 2 backup) |

## Outputs

| Output | Description |
|--------|-------------|
| `aws_vpn_primary` | Primary VPN ID, tunnel addresses, and Netskope POP details |
| `aws_vpn_backup` | Backup VPN ID, tunnel addresses, and Netskope POP details |
| `netskope_tunnel_ids` | All 4 Netskope tunnel IDs |
| `next_steps` | Post-deployment checklist |

## IPSec Configuration

Both AWS and Netskope sides are configured with matching parameters:

| Parameter | Value |
|-----------|-------|
| IKE Version | IKEv2 |
| Phase 1 Encryption | AES-256 |
| Phase 1 Integrity | SHA2-256 |
| Phase 1 DH Group | 14 |
| Phase 1 Lifetime | 7200 seconds |
| Phase 2 Encryption | AES-256-GCM-16 |
| Phase 2 Integrity | SHA2-256 |
| Phase 2 DH Group | 14 |
| Phase 2 Lifetime | 3600 seconds |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| AWS SSO token expired | Run `aws sso login --profile your-profile` |
| `409 Conflict` on Netskope tunnel | Each tunnel has a unique `source_identity` — check for duplicates |
| AWS VPN shows "DOWN" | Tunnels stay down until traffic is initiated or DPD is configured on the remote side |
| TGW destroy takes a long time | TGW deletion waits for VPN attachments to fully detach — this is normal |

## Resources

- [Netskope Terraform Provider](https://registry.terraform.io/providers/netskopeoss/netskope/latest)
- [AWS VPN Connection Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection)
- [AWS Transit Gateway](https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html)
- [Netskope IPSec Documentation](https://docs.netskope.com/en/ipsec/)
