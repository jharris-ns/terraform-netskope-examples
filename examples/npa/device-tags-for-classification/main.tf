# Device Tags for Classification
#
# This example demonstrates the full workflow described in the Netskope
# "Device Tags for Classification" integration guide:
#
#   1. Create a Device Tag — a manual tag that external tools (CrowdStrike,
#      SentinelOne, custom risk-assessment scripts) assign to specific devices
#      via POST /api/v2/devices/device/tags/bulkreplace.
#
#   2. Create a Device Classification Tag — the classification label that
#      appears on devices in the Netskope console and in policy conditions.
#
#   3. Create Device Classification Rules — one per OS platform — that
#      automatically apply the classification label to any device carrying
#      the device tag.
#
# Once deployed, the chain is:
#   external tool assigns Device Tag → Classification Rule fires →
#   Classification label appears on device → NPA / Real-time policies enforce
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. netskope_device_tag requires provider >= 0.4.11.
#
# 2. The Device Tag API does NOT support deletion.
#    Running `terraform destroy` removes the tag from Terraform state but
#    the tag continues to exist in the Netskope tenant. Delete it manually
#    via Settings > Device Classification in the Netskope UI.
#
# 3. The tag_id output is needed by any external tool or script that calls
#    POST /api/v2/devices/device/tags/bulkreplace to assign the tag to devices.
#
# 4. Classification rules fire automatically — no manual step needed after
#    an external tool assigns the Device Tag to a device.
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.4.11"
    }
  }
}

provider "netskope" {}

# =============================================================================
# VARIABLES
# =============================================================================

variable "tag_name" {
  description = "Name for the Device Tag (max 80 chars, alphanumeric, hyphens, spaces)"
  type        = string
  default     = "medium-risk"
}

variable "tag_description" {
  description = "Description for the Device Tag"
  type        = string
  default     = "Assigned by risk-assessment tool to devices with elevated risk score"
}

variable "classification_name" {
  description = "Name for the Device Classification label shown in the Netskope console"
  type        = string
  default     = "Medium Risk"
}

variable "classification_description" {
  description = "Description for the Device Classification label"
  type        = string
  default     = "Devices flagged as medium risk by an external risk assessment tool"
}

# =============================================================================
# STEP 1: DEVICE TAG
# A manual tag that external tools assign to specific devices via API.
# External tools reference this tag by its numeric tag_id (see outputs).
# =============================================================================

resource "netskope_device_tag" "risk" {
  name        = var.tag_name
  description = var.tag_description

  # NOTE: terraform destroy will NOT delete this tag from the Netskope tenant.
  # The Netskope API prohibits programmatic deletion of Device Tags.
  # Remove it manually via Settings > Device Classification in the UI.
}

# =============================================================================
# STEP 2: DEVICE CLASSIFICATION TAG
# The classification label that appears on devices in the Netskope console
# and that policies can reference via device_classification_id.
# =============================================================================

resource "netskope_device_classification_tag" "risk" {
  name        = var.classification_name
  description = var.classification_description
}

# =============================================================================
# STEP 3: DEVICE CLASSIFICATION RULES
# Rules that automatically apply the classification label to devices carrying
# the Device Tag. Create one rule per OS platform you want to cover.
#
# Condition structure (required by the API):
#   $and > $and > $and > check_node
#
# The device_tag_check condition matches devices that have been assigned the
# specified Device Tag ID via the bulkreplace API endpoint.
# =============================================================================

resource "netskope_device_classification_rule" "risk_windows" {
  name  = "${var.tag_name} - Windows"
  label = netskope_device_classification_tag.risk.name
  os    = "windows"

  conditions = jsonencode({
    "$and" = [
      {
        "$and" = [
          {
            "$and" = [
              {
                "device_tag_check" = {
                  "tag_id" = netskope_device_tag.risk.tag_id
                }
              }
            ]
          }
        ]
      }
    ]
  })
}

resource "netskope_device_classification_rule" "risk_mac" {
  name  = "${var.tag_name} - Mac"
  label = netskope_device_classification_tag.risk.name
  os    = "mac"

  conditions = jsonencode({
    "$and" = [
      {
        "$and" = [
          {
            "$and" = [
              {
                "device_tag_check" = {
                  "tag_id" = netskope_device_tag.risk.tag_id
                }
              }
            ]
          }
        ]
      }
    ]
  })
}

# Add rules for other platforms as needed:
#   os = "linux"    — Linux endpoints
#   os = "android"  — Android mobile devices
#   os = "ios"      — iOS mobile devices
#   os = "chromeos" — Chromebook endpoints

# =============================================================================
# OUTPUTS
# =============================================================================

output "device_tag_id" {
  description = <<-EOT
    Numeric ID of the Device Tag. External tools and scripts pass this value
    in the 'tags' array when calling POST /api/v2/devices/device/tags/bulkreplace
    to assign the tag to specific devices.
  EOT
  value       = netskope_device_tag.risk.tag_id
}

output "device_tag_name" {
  description = "Name of the Device Tag"
  value       = netskope_device_tag.risk.name
}

output "classification_tag_id" {
  description = <<-EOT
    Numeric ID of the Device Classification label. Use this in NPA rules via
    device_classification_id = [tostring(output.classification_tag_id.value)]
    or in Real-time Protection policies via the Device Classification condition.
  EOT
  value       = netskope_device_classification_tag.risk.tag_id
}

output "classification_tag_name" {
  description = "Name of the Device Classification label"
  value       = netskope_device_classification_tag.risk.name
}

output "rule_ids" {
  description = "IDs of the Device Classification Rules created"
  value = {
    windows = netskope_device_classification_rule.risk_windows.rule_id
    mac     = netskope_device_classification_rule.risk_mac.rule_id
  }
}

output "bulkreplace_example" {
  description = <<-EOT
    Example curl command to assign this Device Tag to a device.
    Replace <tenant>, <API_TOKEN>, and <nsdeviceuid> with real values.
    The nsdeviceuid is found via GET /api/v2/events/datasearch/clientstatus.
  EOT
  value       = <<-EOT
    curl -X POST "https://<tenant>.goskope.com/api/v2/devices/device/tags/bulkreplace" \
      -H "Authorization: Bearer <API_TOKEN>" \
      -H "Content-Type: application/json" \
      -d '{
        "tags": [${netskope_device_tag.risk.tag_id}],
        "devices": [
          {
            "nsdeviceuid": "<nsdeviceuid>",
            "userkey": "<nsdeviceuid>",
            "hostname": "<hostname>"
          }
        ],
        "device_classifications": []
      }'
  EOT
}
