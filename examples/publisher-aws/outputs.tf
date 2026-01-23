# =============================================================================
# Outputs
# =============================================================================

output "publisher_id" {
  description = "Netskope publisher ID"
  value       = netskope_npa_publisher.this.publisher_id
}

output "ami_used" {
  description = "AMI ID used for deployment"
  value       = data.aws_ami.netskope_publisher.id
}

output "ami_name" {
  description = "AMI name"
  value       = data.aws_ami.netskope_publisher.name
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.publisher.id
}

output "private_ip" {
  description = "Publisher private IP"
  value       = aws_instance.publisher.private_ip
}

output "nat_gateway_ip" {
  description = "NAT Gateway public IP (outbound traffic)"
  value       = aws_eip.nat.public_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}
