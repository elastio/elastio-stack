variable "elastio_server_url" {
  description = "URL of your Elastio tenant. For example `https://mycompany.app.elastio.com`"
  type        = string
  nullable    = false
}

variable "elastio_api_key" {
  description = "Agent API key shown by the Elastio Portal when you add the database"
  sensitive   = true
  type        = string
  nullable    = false
}

variable "database_url" {
  description = "postgres:// URL of the database to watch, for the role created by the setup SQL"
  sensitive   = true
  type        = string
  nullable    = false
}

variable "subnet_ids" {
  description = "Subnets the agent runs in. They must reach the database and the Elastio tenant"
  type        = list(string)
  nullable    = false
}

variable "security_group_ids" {
  description = "Security groups attached to the agent. They need outbound 443 and 2049"
  type        = list(string)
  nullable    = false
}
