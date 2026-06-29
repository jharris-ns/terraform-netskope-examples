# AI Gateway MCP Server Example
#
# Registers a Model Context Protocol (MCP) server with the AIG proxy.
# MCP servers expose tools, resources, and prompts that AI agents can invoke.
# The AIG proxy intermediates and optionally filters which tools are accessible.
#
# Resource naming constraints:
#   - Name must start with "mcp-cust-"
#   - Maximum 19 characters total
#
# Omitting the tools list allows all tools. Providing a tools list restricts
# access to only the named tools (allowlist).
#
# See: https://docs.netskope.com/en/netskope-ai-gateway/

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = "~> 0.4.6"
    }
  }
}

provider "netskope" {
  # Configure via environment variables:
  # NETSKOPE_SERVER_URL = "https://your-tenant.goskope.com/api/v2"
  # NETSKOPE_API_KEY    = "your-api-token"
}

# MCP server with no tool/resource/prompt filtering (allow all)
resource "netskope_aig_mcp_server" "github" {
  name     = "mcp-cust-github"
  host     = "api.githubcopilot.com"
  port     = 443
  path     = "/mcp"
  protocol = "https-system"
}

# MCP server with specific tool allowlist
resource "netskope_aig_mcp_server" "restricted" {
  name     = "mcp-cust-jira"
  host     = "mcp.atlassian.internal.company.com"
  port     = 443
  path     = "/mcp"
  protocol = "https-system"

  tools = [
    "create_issue",
    "get_issue",
    "search_issues",
  ]
}

output "github_server_id" {
  value = netskope_aig_mcp_server.github.id
}