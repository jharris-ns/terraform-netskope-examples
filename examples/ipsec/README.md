# IPSec Tunnel Examples

Terraform examples for managing [Netskope IPSec tunnels](https://docs.netskope.com/en/ipsec-tunnel/) for traffic steering.

## Prerequisites

- Netskope tenant with **IPSec/GRE** licensed
- REST API v2 access enabled
- Terraform >= 1.0
- For AWS examples: AWS CLI configured with appropriate permissions

## Examples

| Example | Difficulty | Description |
|---------|------------|-------------|
| [pop-management/](./pop-management/) | Simple | Discover available POPs and create a basic IPSec tunnel |
| [vpn/](./vpn/) | Intermediate | IPSec tunnel steering with primary and backup tunnels |
| [aws-transitgateway-vpn/](./aws-transitgateway-vpn/) | Advanced | AWS Transit Gateway + Netskope IPSec integration |

## Key Concepts

### IPSec POPs
Netskope IPSec tunnels terminate at Points of Presence (POPs). Use the `netskope_ip_sec_po_ps_list` data source to discover available POPs and select the closest one.

### AWS Transit Gateway Integration
The `aws-transitgateway-vpn` example shows how to connect an AWS Transit Gateway to Netskope via IPSec tunnels, enabling cloud workloads to route through Netskope for inspection.