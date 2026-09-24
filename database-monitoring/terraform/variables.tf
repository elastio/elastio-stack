# The variable names here are a contract: the product renders a filled-in
# module call from them. Rename one and the rendered block stops applying.

variable "name" {
  description = "What the product shows for this agent. Also the ECS cluster, service and task family name, sanitised to the characters ECS allows."
  type        = string
}

variable "server_url" {
  description = "Base URL of the server the agent reports to."
  type        = string
}

variable "api_key" {
  description = "Bearer token the agent presents to the server. Stored in Secrets Manager, never in the task definition."
  type        = string
  sensitive   = true
}

variable "database_url" {
  description = "postgres:// URL of the database to watch, for a role with REPLICATION. Stored in Secrets Manager, never in the task definition."
  type        = string
  sensitive   = true
}

variable "slot" {
  description = "Name of the existing pgoutput replication slot. The agent never creates or drops one."
  type        = string
  default     = "elastio_monitor"
}

variable "publication" {
  description = "Name of the publication whose tables are streamed."
  type        = string
  default     = "elastio_monitor"
}

variable "subnet_ids" {
  description = "Subnets the task runs in. They must reach the database and the server URL."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "subnet_ids must contain at least one subnet."
  }
}

variable "security_group_ids" {
  description = "Security groups attached to the task. The database's own security group must admit them on its port."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "security_group_ids must contain at least one security group. The EFS mount targets admit NFS only from these groups."
  }
}

variable "image" {
  description = "Agent image. The default is the agent release this module version was tested with. Pin a version; :latest moves. Needs 0.1.5 or later: older agents read only the QUELL_* variable names."
  type        = string
  default     = "public.ecr.aws/elastio/elastio-database-monitoring-agent:0.1.5"
}

variable "assign_public_ip" {
  description = "Give the task a public IP. Needed only when the subnets have no NAT gateway and the server URL is on the internet."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps the agent's log."
  type        = number
  default     = 7

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value CloudWatch Logs accepts: 0 (never expire), 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288 or 3653."
  }
}

variable "persistent_ledger" {
  description = "Keep the agent's ledger on an encrypted EFS file system so it survives task replacement. When false, the ledger is on the task's ephemeral storage and every replacement starts it empty, after which findings standing at the time can never be explained by later activity."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource the module creates."
  type        = map(string)
  default     = {}
}
