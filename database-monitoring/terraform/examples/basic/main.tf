module "elastio_database_monitoring_agent" {
  source = "../../"

  name         = "orders-db-prod"
  server_url   = var.elastio_server_url
  api_key      = var.elastio_api_key
  database_url = var.database_url

  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # The smallest size, and the default. Raise both when the Elastio UI says a
  # transaction was too large for the agent to hold; see Sizing in the
  # module's README.
  task_cpu    = 256
  task_memory = 512
}
