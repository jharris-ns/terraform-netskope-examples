variable "apps" {
  description = "Client-based private apps to create in this tenant, keyed by private_app_name. The root module pre-filters this to the apps targeting this tenant."
  type = map(object({
    hostname = string
    port     = string
    protocol = optional(string, "tcp")
    tags     = optional(list(string), [])
  }))
}

variable "publisher_name" {
  description = "Name of an existing publisher in this tenant to attach the apps to"
  type        = string
}

variable "tenant_tag" {
  description = "Tag applied to every app so it is traceable back to the tenant/module instance that created it (e.g. \"tenant-a\")"
  type        = string
}
