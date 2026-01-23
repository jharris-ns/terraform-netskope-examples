# Browser App Example

Creates a browser-accessible private application for internal web apps like wikis, dashboards, or admin panels.

## What This Creates

- One private app with clientless (browser) access enabled
- User portal access enabled
- Assigns to first available publisher

## Prerequisites

- At least one registered NPA publisher
- Netskope tenant with REST API v2 access

## Usage

1. Configure credentials:
   ```bash
   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
   export NETSKOPE_API_KEY="your-api-token"
   ```

2. Update `main.tf` with your application details:
   - `private_app_name` - Display name for the app
   - `private_app_hostname` - The hostname users will access
   - `real_host` - The actual IP or hostname of the backend server

3. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Outputs

| Output | Description |
|--------|-------------|
| `browser_access_url` | URL for accessing the app via browser |
| `app_id` | The ID of the created private application |

## Cleanup

```bash
terraform destroy
```
