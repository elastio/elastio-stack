output "cluster_arn" {
  description = "ARN of the ECS cluster the agent runs in."
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "log_group_name" {
  description = "CloudWatch log group the agent writes to."
  value       = aws_cloudwatch_log_group.this.name
}

output "execution_role_arn" {
  description = "IAM role ECS uses to pull the image, read the three secrets and write logs."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "IAM role the running container assumes. The agent has no AWS code; with persistent state the role may mount the state file system, and nothing else."
  value       = aws_iam_role.task.arn
}

output "ledger_file_system_id" {
  description = "ID of the EFS file system holding the agent's state, or null when persistent_ledger is false."
  value       = var.persistent_ledger ? aws_efs_file_system.ledger[0].id : null
}

output "hash_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the agent's key. It must stay stable for the life of the agent's state."
  value       = aws_secretsmanager_secret.hash_secret.arn
}
