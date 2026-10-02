# After bootstrap, Elastio owns image selection. Terraform reads the service's
# currently deployed images before changing size or infrastructure, so a later
# apply cannot restore an obsolete module image pin.
variable "runtime_updates" {
  description = "Preserve images selected by Elastio when applying infrastructure/size changes. Enable after the ECS service has first been created."
  type        = bool
  default     = false
}

data "aws_ecs_service" "runtime" {
  count        = var.runtime_updates ? 1 : 0
  service_name = local.ecs_name
  cluster_arn  = aws_ecs_cluster.this.arn
}

data "aws_ecs_task_definition" "runtime" {
  count           = var.runtime_updates ? 1 : 0
  task_definition = data.aws_ecs_service.runtime[0].task_definition
}

locals {
  runtime_images = var.runtime_updates ? {
    for container in jsondecode(data.aws_ecs_task_definition.runtime[0].container_definitions) : container.name => container.image
  } : {}
}
