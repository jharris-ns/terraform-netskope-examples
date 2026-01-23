output "publisher_tokens" {
  description = "Registration tokens for the publishers (use these to register the publisher VMs)"
  sensitive   = true
  value = {
    primary   = netskope_npa_publisher_token.primary_token.token
    secondary = netskope_npa_publisher_token.secondary_token.token
  }
}

output "web_app_hostname" {
  description = "Hostname for web application access via NPA client"
  value       = netskope_npa_private_app.web_app.private_app_hostname
}

output "ssh_hostname" {
  description = "Hostname for SSH access via NPA client"
  value       = netskope_npa_private_app.ssh_servers.private_app_hostname
}

output "publishers" {
  description = "Created publishers"
  value = {
    primary = {
      id   = netskope_npa_publisher.primary.publisher_id
      name = netskope_npa_publisher.primary.publisher_name
    }
    secondary = {
      id   = netskope_npa_publisher.secondary.publisher_id
      name = netskope_npa_publisher.secondary.publisher_name
    }
  }
}
