# Full Deployment Example

A complete NPA deployment including publishers, private applications, and access policies for a datacenter environment.

## What This Creates

**Publishers:**
- Primary and secondary publishers for high availability
- Registration tokens for both

**Private Applications:**
- Web portal (browser-accessible via Netskope portal)
- SSH access (client-only, restricted to admin groups)

**Access Policies:**
- Web portal access for all authenticated users
- SSH access restricted to infrastructure admins

## Prerequisites

- Netskope tenant with REST API v2 access
- Infrastructure to deploy publishers (VMs or containers)
- User groups configured in your IdP

## Usage

1. Configure credentials:
   ```bash
   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
   export NETSKOPE_API_KEY="your-api-token"
   ```

2. Copy and configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit with your datacenter name and admin groups
   ```

3. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. Get publisher registration tokens:
   ```bash
   terraform output -json publisher_tokens
   ```

5. Deploy publishers using the tokens, then verify they connect.

## Outputs

| Output | Description |
|--------|-------------|
| `publisher_tokens` | Registration tokens (sensitive) |
| `web_portal_url` | URL for browser access to portal |
| `ssh_hostname` | Hostname for SSH via NPA client |
| `publishers` | Publisher IDs and names |

## Next Steps

After deployment:
1. Register publisher VMs/containers with the tokens
2. Verify publishers show "Connected" in Netskope console
3. Test web portal access via browser
4. Test SSH access via NPA client

## Cleanup

```bash
terraform destroy
```

**Warning**: This will remove all publishers, apps, and policies.
