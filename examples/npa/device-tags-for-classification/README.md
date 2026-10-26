# Device Tags for Classification

Integrate external risk-assessment tools with Netskope device posture using the Device Tags API. Devices flagged by third-party tools automatically receive Netskope classification labels, which then drive access policy enforcement in NPA and Real-time Protection.

**Difficulty:** Intermediate
**Provider version:** >= 0.4.11

## Overview

Netskope has two separate device labelling systems that work together:

| System | API path | Applied by | Used for |
|--------|----------|-----------|---------|
| **Device Tags** | `/devices/device/tags` | External tools via API (manual) | Tagging individual devices based on real-time risk data |
| **Device Classification** | `/deviceclassification/tags` + `/deviceclassification/rules` | Rules engine (automatic) | Policy conditions — NPA rules, Real-time Protection |

This example connects the two: an external tool assigns a Device Tag to a device; a Classification Rule detects that tag and promotes it to a Classification label; policies enforce access based on the label.

```
External tool                 Netskope
─────────────                 ────────
Risk assessment               Device Classification Rule
    │                                │
    │  POST /bulkreplace             │  device_tag_check {tag_id}
    ▼                               ▼
Device Tag ──────────────── Device Classification label ──▶ NPA / RT policies
(manual)                    (automatic, rule-based)
```

## Quick Start

```bash
cd examples/npa/device-tags-for-classification

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init
terraform plan
terraform apply
```

After `apply`, Terraform outputs the Device Tag ID. Pass this to the external tool or script that assigns tags to devices via `POST /api/v2/devices/device/tags/bulkreplace`.

## Prerequisites

- Netskope tenant with **Device Classification API** access enabled
- API token with **Device Classification** (Manage) and **Devices** (Manage) permissions set in Settings > Tools > REST API v2 (Access Control > NS Client functional area)
- Provider version >= 0.4.11

## What This Creates

| Resource | Name | Purpose |
|----------|------|---------|
| `netskope_device_tag` | `medium-risk` | Manual tag for external tools to assign to devices |
| `netskope_device_classification_tag` | `Medium Risk` | Classification label visible in console and policies |
| `netskope_device_classification_rule` | `medium-risk - Windows` | Classifies Windows devices carrying the Device Tag |
| `netskope_device_classification_rule` | `medium-risk - Mac` | Classifies Mac devices carrying the Device Tag |

Customise via variables — see [Variables](#variables) below.

## Workflow After Deployment

### 1. Find a device's nsdeviceuid

```bash
curl "https://<tenant>.goskope.com/api/v2/events/datasearch/clientstatus?starttime=<unix>&endtime=<unix>&fields=nsdeviceuid,hostname,user,os" \
  -H "Authorization: Bearer <API_TOKEN>"
```

### 2. Assign the Device Tag to the device

Use the `device_tag_id` output from `terraform output`:

```bash
curl -X POST "https://<tenant>.goskope.com/api/v2/devices/device/tags/bulkreplace" \
  -H "Authorization: Bearer <API_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "tags": [<device_tag_id>],
    "devices": [{"nsdeviceuid": "<uid>", "userkey": "<uid>", "hostname": "<hostname>"}],
    "device_classifications": []
  }'
```

### 3. Verify in the Netskope console

The device now shows **Device Classification: Medium Risk, Managed** under Security Cloud Platform > Devices.

### 4. Use the classification in a policy

**NPA rule** (reference the classification tag ID from `terraform output classification_tag_id`):

```hcl
resource "netskope_npa_rules" "block_risky_devices" {
  rule_name = "block-medium-risk-devices"
  enabled   = "1"
  group_id  = local.default_group.id

  rule_data = {
    policy_type           = "private-app"
    match_criteria_action = { action_name = "deny" }
    private_apps          = ["my-internal-app"]
    access_method         = ["Client"]

    device_classification_id = [tostring(data.terraform_remote_state.classification.outputs.classification_tag_id)]
  }

  rule_order = { order = "top" }
}
```

See [npa/device-classification/](../device-classification/) for a complete NPA rule example.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `tag_name` | `medium-risk` | Device Tag name (max 80 chars, alphanumeric, hyphens, spaces) |
| `tag_description` | *(see main.tf)* | Device Tag description |
| `classification_name` | `Medium Risk` | Classification label shown in the console and policies |
| `classification_description` | *(see main.tf)* | Classification label description |

Customise via `terraform.tfvars`:

```hcl
tag_name               = "high-risk"
tag_description        = "Assigned by CrowdStrike when ZTA score drops below threshold"
classification_name    = "High Risk"
classification_description = "Devices with elevated risk score from CrowdStrike ZTA"
```

## Key Patterns

### Conditions structure

The `conditions` field in `netskope_device_classification_rule` requires a specific nesting depth (`$and > $and > $and > check_node`):

```hcl
conditions = jsonencode({
  "$and" = [
    {
      "$and" = [
        {
          "$and" = [
            {
              "device_tag_check" = {
                "tag_id" = netskope_device_tag.risk.tag_id  # int, not string
              }
            }
          ]
        }
      ]
    }
  ]
})
```

### Multiple conditions (AND logic)

Combine a device tag check with an OS version requirement:

```hcl
"$and" = [
  { "device_tag_check"    = { "tag_id"          = netskope_device_tag.risk.tag_id } },
  { "min_os_version_check" = { "min_os_version" = "10.0.0" } }
]
```

### Multiple platforms

Add additional `netskope_device_classification_rule` resources for each OS you want to cover. Valid values for `os`: `windows`, `mac`, `linux`, `android`, `ios`, `chromeos`.

## Destroy Behaviour

| Resource | Destroyed? | Notes |
|----------|-----------|-------|
| `netskope_device_classification_rule` | Yes | Deleted from tenant |
| `netskope_device_classification_tag` | Yes | Deleted from tenant |
| `netskope_device_tag` | **No** | API prohibits programmatic deletion — remove manually via Settings > Device Classification in the Netskope UI |

## Related Examples

- [npa/device-classification/](../device-classification/) — Use classification tags in NPA access rules
- [npa/policy-as-code/](../policy-as-code/) — Combine device posture with team-based allow/deny rules
