# =============================================================================
# Minimum Viable AWS Infrastructure for Testing
# =============================================================================
# This file creates a Transit Gateway needed to test the Netskope TGW
# integration. Delete this file if you already have a Transit Gateway.
# =============================================================================

resource "aws_ec2_transit_gateway" "test" {
  description                     = "Netskope IPSec test TGW"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  vpn_ecmp_support                = "enable"

  tags = {
    Name = "netskope-test-tgw"
  }
}
