# Custom Categories for Real-time Protection Policies
#
# This example demonstrates how to combine URL lists into custom categories —
# the object that ties URL lists and destination profiles together so they
# can be referenced in Real-time Protection policies.
#
# Use case: A Terraform-managed URL list has no effect in policy until it is
# attached to a custom category. This example shows the complete chain:
#
#   URL List (block)   ─┐
#                        ├──> Custom Category ──> Real-time Protection Policy
#   URL List (allow)   ─┘  (exception)
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. Custom categories are auto-deployed after create/update. There is no
#    separate deploy step required.
#
# 2. included_url_lists and excluded_url_lists take the numeric string ID of
#    the URL list. Use tostring() when referencing an integer id attribute.
#
# 3. included_predefined_categories takes numeric string IDs of Netskope's
#    built-in categories (e.g. "500" for Social Media). Find IDs in the
#    Netskope UI under Policies > Web > Categories.
#
# 4. The API token must have the objects_custom_category API group with rwa
#    permission (deploy requires the 'a' level).
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.4.8"
    }
  }
}

provider "netskope" {}

# =============================================================================
# URL LISTS
# =============================================================================

# Sites that should be blocked for general employees
resource "netskope_urllist" "social_media_block" {
  name = "social-media-sites"
  data = {
    urls = [
      "facebook.com",
      "instagram.com",
      "tiktok.com",
      "twitter.com",
      "x.com",
    ]
    type = "exact"
  }
}

# Sites that the marketing team is allowed to access
resource "netskope_urllist" "marketing_exceptions" {
  name = "marketing-social-media-allowed"
  data = {
    urls = [
      "linkedin.com",
      "youtube.com",
    ]
    type = "exact"
  }
}

# Internal domains that should never be subject to content inspection
resource "netskope_urllist" "internal_bypass" {
  name = "internal-domains-bypass"
  data = {
    urls = [
      ".*\\.corp\\.example\\.com",
      ".*\\.internal\\.example\\.com",
    ]
    type = "regex"
  }
}

# =============================================================================
# CUSTOM CATEGORIES
# =============================================================================

# Category that groups social media sites for use in block policies
# Marketing team exceptions are excluded so their policy can allow these URLs
resource "netskope_custom_category" "social_media" {
  name        = "Social Media - Employee Blocked"
  description = "Social media sites subject to the general employee block policy. LinkedIn and YouTube excluded for marketing team exception. Managed by Terraform."

  included_url_lists = [tostring(netskope_urllist.social_media_block.id)]
  excluded_url_lists = [tostring(netskope_urllist.marketing_exceptions.id)]
}

# Category for marketing team that allows social media access
resource "netskope_custom_category" "social_media_marketing" {
  name        = "Social Media - Marketing Allowed"
  description = "Social media sites allowed for the marketing team. Managed by Terraform."

  included_url_lists = [tostring(netskope_urllist.marketing_exceptions.id)]
}

# Bypass category — URLs in this category skip content inspection entirely
resource "netskope_custom_category" "internal_bypass" {
  name        = "Internal Domains - Bypass"
  description = "Internal corporate domains that bypass content inspection. Managed by Terraform."

  included_url_lists = [tostring(netskope_urllist.internal_bypass.id)]
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# Read back one category by ID to verify it deployed correctly
data "netskope_custom_category" "social_media" {
  id         = netskope_custom_category.social_media.id
  depends_on = [netskope_custom_category.social_media]
}

# List all custom categories on the tenant
data "netskope_custom_category_list" "all" {
  depends_on = [
    netskope_custom_category.social_media,
    netskope_custom_category.social_media_marketing,
    netskope_custom_category.internal_bypass,
  ]
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "custom_categories" {
  description = "Custom categories created in this configuration"
  value = {
    social_media = {
      id   = netskope_custom_category.social_media.id
      name = netskope_custom_category.social_media.name
    }
    social_media_marketing = {
      id   = netskope_custom_category.social_media_marketing.id
      name = netskope_custom_category.social_media_marketing.name
    }
    internal_bypass = {
      id   = netskope_custom_category.internal_bypass.id
      name = netskope_custom_category.internal_bypass.name
    }
  }
}

output "all_category_names" {
  description = "Names of all custom categories on this tenant"
  value       = [for c in data.netskope_custom_category_list.all.elements : c.name]
}
