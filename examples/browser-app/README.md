# Browser App Examples

Creates browser-accessible private applications demonstrating three common patterns.

## What This Creates

| Resource | Pattern | Key Fields |
|----------|---------|------------|
| Internal Wiki | Basic browser app | Auto-generated Netskope URL |
| Engineering Dashboard | Custom hostname | `custom_host`, `hide_app_in_portal`, `upgrade_insecure_requests` |
| Internal API Gateway | URI auth bypass | `allow_uri_bypass`, `bypass_uris`, `uribypass_header_value` |

## Browser-Only Fields

The following fields only apply to browser-based apps (`clientless_access = true`). Do not use them on client-based apps.

| Field | Description |
|-------|-------------|
| `custom_host` | **Read-only / computed.** Friendly FQDN derived from the CN of a certificate uploaded via the Netskope UI. Cannot be set directly via the API or Terraform. After uploading a cert in the UI, run `terraform refresh` to see the value. Also requires a DNS CNAME pointing to the Public Host URL. |
| `hide_app_in_portal` | Controls visibility in the Browser Access User Portal. Requires the User Portal feature flag on your tenant. |
| `enterprise_browser` | Enables Enterprise Browser features. Requires the `npa_mixed_content_enabled` feature flag on your tenant. |
| `upgrade_insecure_requests` | Upgrades HTTP requests to HTTPS when proxying to the backend. Requires `enterprise_browser = true`. |
| `allow_uri_bypass` | Enables URI authentication bypass for specific paths. Requires feature flag. |
| `bypass_uris` | List of URI paths that skip SAML authentication (max 20 per app). Requires feature flag. |
| `uribypass_header_value` | Shared secret (8-64 chars) sent via `X-NSKP-URIBYPASS` header for bypass requests. Requires feature flag. |
| `allow_unauthenticated_cors` | Allows CORS OPTIONS requests without authentication. |

## Prerequisites

- At least one registered NPA publisher
- Netskope tenant with REST API v2 access
- SAML Reverse Proxy configured for Browser Access
- (Custom hostname) Certificate and key pair uploaded via the Netskope UI — `custom_host` is read-only in the API and derived from the cert CN
- (URI bypass) Feature flag enabled by Netskope Support

## Usage

1. Configure credentials:
   ```bash
   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
   export NETSKOPE_API_KEY="your-api-token"
   ```

2. Update `main.tf` with your application details (hostnames, URIs, secrets).

3. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Outputs

| Output | Description |
|--------|-------------|
| `wiki_app_hostname` | Auto-generated hostname for the basic browser app |
| `dashboard_custom_host` | Custom hostname for the dashboard app |
| `dashboard_app_hostname` | Netskope-generated hostname (use as CNAME target) |
| `api_app_hostname` | Hostname for the API gateway with URI bypass |

## References

- [Configure Browser Access for Private Apps](https://docs.netskope.com/en/configure-browser-access-for-private-apps/)
- [Browser Access Authentication Bypass for URIs](https://docs.netskope.com/en/browser-access-authentication-bypass-for-uris/)
- [Enable Browser Access Apps with a User Portal](https://docs.netskope.com/en/enable-browser-access-apps-with-a-user-portal/)

## Cleanup

```bash
terraform destroy
```