# Upgrading to Netskope Provider 0.3.4

This guide covers upgrading the Netskope Terraform Provider from version 0.3.2 to 0.3.4, including breaking changes, state file considerations, and step-by-step migration instructions.

## Summary of Changes (0.3.2 → 0.3.4)

### Schema Changes

| Resource/Data Source | Change |
|---------------------|--------|
| `netskope_npa_private_app` | `private_app_name` and `private_app_protocol` are now writable attributes |
| `netskope_npa_rules` | `rule_id` is now a string (was integer) |
| `netskope_npa_publishers_list` | Data path changed from `data[0]` to `data.publishers[0]` |

### New Resources

- `netskope_npa_local_broker` - Manage local broker lifecycle
- `netskope_npa_local_broker_config` - Configure local broker hostname (tenant-wide)
- `netskope_npa_local_broker_token` - Generate local broker registration tokens

### New Data Sources

- `netskope_npa_local_brokers_list` - List all local brokers
- `netskope_npa_local_broker_config` - Read current hostname configuration

### Provider Improvements

- Native environment variable support (`NETSKOPE_SERVER_URL`, `NETSKOPE_API_KEY`)
- Reduced state drift from API response normalization
- Added `disconnected` publisher status

---

## Breaking Changes

### 1. Private App Schema Changes

**Affected attributes in `netskope_npa_private_app`:**

| Attribute | 0.3.2 | 0.3.4 |
|-----------|-------|-------|
| `private_app_name` | Read-only (computed) | Writable (required) |
| `private_app_protocol` | Read-only (computed) | Writable (required) |

**Impact**: Configurations written for 0.3.4 will fail validation on 0.3.2.

**0.3.2 configuration** (attributes derived from API):
```hcl
resource "netskope_npa_private_app" "example" {
  private_app_hostname = "app.internal.company.com"
  real_host            = "app.internal.local"
  # private_app_name and private_app_protocol were computed
  # ...
}
```

**0.3.4 configuration** (attributes explicitly set):
```hcl
resource "netskope_npa_private_app" "example" {
  private_app_name     = "My Application"        # Now required
  private_app_hostname = "app.internal.company.com"
  private_app_protocol = "https"                 # Now required
  real_host            = "app.internal.local"
  # ...
}
```

### 2. New Local Broker Resources

The following resources are **new in 0.3.3+** and do not exist in 0.3.2:

| Type | Name |
|------|------|
| Resource | `netskope_npa_local_broker` |
| Resource | `netskope_npa_local_broker_config` |
| Resource | `netskope_npa_local_broker_token` |
| Data Source | `netskope_npa_local_brokers_list` |
| Data Source | `netskope_npa_local_broker_config` |

**Impact**: Any configuration using local broker resources requires 0.3.4+.

### 3. Publisher Data Source Path

**0.3.2**:
```hcl
data.netskope_npa_publishers_list.all.data[0].publisher_name
```

**0.3.4**:
```hcl
data.netskope_npa_publishers_list.all.data.publishers[0].publisher_name
```

**Impact**: Existing configurations referencing publisher data will need path updates.

### 4. Rule ID Type Change

**0.3.2**: `rule_id` returned as integer
**0.3.4**: `rule_id` returned as string

**Impact**: Code comparing or using `rule_id` may need type conversion adjustments.

---

## State File Considerations

### Existing State with Private Apps

If you have private apps managed by Terraform with 0.3.2 state:

1. **State contains computed values** for `private_app_name` and `private_app_protocol`
2. **After upgrade**, Terraform will see these as "new" attributes in your config
3. **Plan will show changes** even if the values match the existing resource

**Resolution options:**

**Option A: Let Terraform update in-place (Recommended)**
```bash
# After upgrading provider and updating config
terraform plan   # Review changes
terraform apply  # Apply - should be no-op if values match
```

**Option B: Refresh state first**
```bash
terraform refresh  # Update state with current API values
terraform plan     # Should show no changes if config matches
```

**Option C: Import fresh (for complex issues)**
```bash
# Remove from state
terraform state rm netskope_npa_private_app.example

# Re-import with correct ID
terraform import netskope_npa_private_app.example <app_id>
```

### State with Publisher References

If your state references publishers using the old data path:

1. Update your configuration to use the new path
2. Run `terraform plan` - no actual resource changes should occur
3. The state will be updated on next apply

### State with NPA Rules

The `rule_id` type change from integer to string should be handled automatically by Terraform's type coercion. However, if you have custom scripts or outputs that expect an integer:

```hcl
# If you need an integer for some reason
output "rule_id_as_number" {
  value = tonumber(netskope_npa_rules.example.id)
}
```

---

## Upgrade Steps

### Pre-Upgrade Checklist

- [ ] Backup your current state file
- [ ] Document current resource IDs (for recovery if needed)
- [ ] Review the breaking changes above
- [ ] Test in non-production environment first

### Step 1: Backup State

```bash
# Local state
cp terraform.tfstate terraform.tfstate.backup-0.3.2

# Remote state (S3 example)
aws s3 cp s3://bucket/path/terraform.tfstate ./terraform.tfstate.backup-0.3.2
```

### Step 2: Update Provider Version

Update your `main.tf` or `versions.tf`:

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.4"
    }
  }
}
```

### Step 3: Update Private App Configurations

Add the now-required attributes to all `netskope_npa_private_app` resources:

```hcl
resource "netskope_npa_private_app" "example" {
  # Add these two attributes
  private_app_name     = "Application Name"
  private_app_protocol = "https"  # or "ssh", "rdp", "tcp"

  # Existing attributes remain unchanged
  private_app_hostname = "app.internal.company.com"
  real_host            = "app.internal.local"
  # ...
}
```

**Tip**: Use the Netskope UI or API to find the current values:
```bash
curl -s -H "Netskope-Api-Token: $NETSKOPE_API_KEY" \
  "$NETSKOPE_SERVER_URL/steering/apps/private" | jq '.data'
```

### Step 4: Update Publisher Data References

If you reference publisher data, update the path:

```hcl
# Old (0.3.2)
locals {
  publisher = data.netskope_npa_publishers_list.all.data[0]
}

# New (0.3.4)
locals {
  publisher = data.netskope_npa_publishers_list.all.data.publishers[0]
}
```

### Step 5: Reinitialize Terraform

```bash
# Remove old provider
rm -rf .terraform .terraform.lock.hcl

# Reinitialize with new provider
terraform init
```

### Step 6: Review Plan

```bash
terraform plan
```

**Expected output:**
- Private apps may show updates for `private_app_name` and `private_app_protocol` (should be no-op if values match)
- No unexpected destroys or recreates

**Warning signs:**
- Resources showing as "must be replaced" - investigate before proceeding
- Missing resources - check import requirements
- Errors about unknown attributes - review configuration updates

### Step 7: Apply Changes

```bash
terraform apply
```

### Step 8: Verify

```bash
# Confirm state is clean
terraform plan
# Expected: "No changes. Your infrastructure matches the configuration."
```

---

## Troubleshooting

### Error: Invalid Configuration for Read-Only Attribute

```
Error: Invalid Configuration for Read-Only Attribute
  with netskope_npa_private_app.example,
  on main.tf line 10:
  10:   private_app_name = "My App"
```

**Cause**: You're using 0.3.4 configuration syntax with 0.3.2 provider.

**Solution**: Ensure provider version is updated and run `terraform init`.

### Error: Provider does not support resource type

```
Error: Invalid resource type
  The provider netskopeoss/netskope does not support resource type
  "netskope_npa_local_broker".
```

**Cause**: Local broker resources require 0.3.3+.

**Solution**: Update to provider version 0.3.4 or remove local broker resources.

### State Drift After Upgrade

If `terraform plan` shows unexpected changes:

```bash
# Refresh state from API
terraform refresh

# Check plan again
terraform plan
```

If drift persists, the API values may differ from your configuration. Update your config to match current values or accept the changes.

### Import Errors

If you need to re-import a resource:

```bash
# Find the resource ID
curl -s -H "Netskope-Api-Token: $NETSKOPE_API_KEY" \
  "$NETSKOPE_SERVER_URL/steering/apps/private" | jq '.data[] | {id: .app_id, name: .app_name}'

# Import
terraform import netskope_npa_private_app.example <app_id>
```

### Rollback Procedure

If you need to rollback to 0.3.2:

1. **Restore state backup**:
   ```bash
   cp terraform.tfstate.backup-0.3.2 terraform.tfstate
   ```

2. **Revert provider version**:
   ```hcl
   netskope = {
     source  = "netskopeoss/netskope"
     version = "= 0.3.2"
   }
   ```

3. **Revert configuration** (remove `private_app_name`, `private_app_protocol`, and local broker resources)

4. **Reinitialize**:
   ```bash
   rm -rf .terraform .terraform.lock.hcl
   terraform init
   ```

---

## Compatibility Matrix

| Example | 0.3.2 | 0.3.4 | Notes |
|---------|-------|-------|-------|
| browser-app | No | Yes | Requires `private_app_name`, `private_app_protocol` |
| client-app | No | Yes | Requires `private_app_name`, `private_app_protocol` |
| full-deployment | No | Yes | Requires `private_app_name`, `private_app_protocol` |
| local-broker-management | No | Yes | New resources not in 0.3.2 |
| policy-as-code | Yes | Yes | Compatible with both |
| private-app-inventory | No | Yes | Requires `private_app_name`, `private_app_protocol` |
| publisher-aws | Yes | Yes | Compatible with both |
| publisher-management | Yes | Yes | Compatible with both |

---

## Getting Help

- [Provider Documentation](https://registry.terraform.io/providers/netskopeoss/netskope/latest/docs)
- [GitHub Issues](https://github.com/netskopeoss/terraform-provider-netskope/issues)
- [Netskope Documentation](https://docs.netskope.com)
