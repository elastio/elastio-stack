# The deployment updater, as a second ECS service in the agent's cluster.
#
# Fargate has no host to run the updater on, so it runs as its own task. It
# asks Elastio for update work with the agent's API key, resolves and verifies
# the image Elastio names, and deploys it by registering a new revision of the
# agent's task definition with that image and pointing the agent's service at
# it. That is all it may do in AWS: its task role can read and update the
# agent's service, register revisions of the agent's task family, and pass the
# agent's two roles to ECS -- and nothing else.

variable "updater" {
  description = "Run Elastio's deployment updater as a second ECS service in the agent's cluster, so an agent update started from Elastio is applied to this service. Requires runtime_updates = true, so a later apply keeps the image the updater deployed. Enable both after the first apply: runtime_updates reads the service, which must exist."
  type        = bool
  default     = false

  validation {
    condition     = !var.updater || var.runtime_updates
    error_message = "updater = true needs runtime_updates = true. Without it, the next apply would put back the module's image over the one the updater deployed. Both need the agent's service to exist: enable them after the first apply."
  }
}

variable "updater_image" {
  description = "Deployment updater image, used when updater is true. The default follows update_channel: the updater released with this module version for production, the latest development build for development."
  type        = string
  default     = null
}

variable "update_channel" {
  description = "Release channel the updater installs agents from: production or development."
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "development"], var.update_channel)
    error_message = "update_channel must be production or development."
  }
}

variable "agent_id" {
  description = "The agent's ID in Elastio, given to the updater. Optional: when empty, the updater asks Elastio for it with the agent's API key."
  type        = string
  default     = ""
}

locals {
  updater = var.updater

  updater_default_image = {
    production  = "public.ecr.aws/elastio/elastio-database-monitoring-updater:0.1.10"
    development = "public.ecr.aws/elastio-development/elastio-database-monitoring-updater:latest"
  }
  updater_image = coalesce(var.updater_image, local.updater_default_image[var.update_channel])

  # ECS names are at most 255 characters; leave room for the suffix.
  updater_ecs_name = "${substr(local.ecs_name, 0, 247)}-updater"

  # The agent's task family, any revision. Registering a revision and pointing
  # the service at one are both limited to it.
  agent_task_family_arn = "${aws_ecs_task_definition.this.arn_without_revision}:*"

  updater_container = {
    name      = "${local.prefix}-updater"
    image     = local.updater_image
    essential = true

    environment = [
      { name = "ELASTIO_DBMON_SERVER_URL", value = var.server_url },
      { name = "ELASTIO_DBMON_AGENT_ID", value = var.agent_id },
      { name = "ELASTIO_DBMON_DEPLOYMENT", value = "ecs" },
      { name = "ELASTIO_DBMON_UPDATE_CHANNEL", value = var.update_channel },
      { name = "ELASTIO_DBMON_ECS_CLUSTER", value = aws_ecs_cluster.this.name },
      { name = "ELASTIO_DBMON_ECS_SERVICE", value = aws_ecs_service.this.name },
      { name = "ELASTIO_DBMON_ECS_CONTAINER", value = local.agent_container_base.name },
    ]

    # The agent's own API key, from the agent's secret: the updater acts for
    # this agent and no other.
    secrets = [
      { name = "ELASTIO_DBMON_API_KEY", valueFrom = aws_secretsmanager_secret.api_key.arn },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-region"        = local.region
        "awslogs-stream-prefix" = "updater"
      }
    }
  }
}

# The updater's execution role: pull the image, write the log, and read the
# agent's API key -- not the database URL, not the hash key.

resource "aws_iam_role" "updater_execution" {
  count = local.updater ? 1 : 0

  # "elastio-dbmon-" (14) + 16 + "-uexec-" (7) = 37, within IAM's 38.
  name_prefix        = "${local.prefix}-${local.short_name}-uexec-"
  description        = "ECS task execution role of the Elastio database monitoring agent's updater"
  assume_role_policy = local.ecs_tasks_assume_role_policy
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "updater_execution" {
  count = local.updater ? 1 : 0

  role       = aws_iam_role.updater_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "updater_read_api_key" {
  count = local.updater ? 1 : 0

  name = "read-${local.prefix}-api-key"
  role = aws_iam_role.updater_execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.api_key.arn
      },
    ]
  })
}

# The updater's task role: what the updater process calls AWS with.

resource "aws_iam_role" "updater_task" {
  count = local.updater ? 1 : 0

  # "elastio-dbmon-" (14) + 16 + "-utask-" (7) = 37, within IAM's 38.
  name_prefix        = "${local.prefix}-${local.short_name}-utask-"
  description        = "ECS task role of the Elastio database monitoring agent's updater: deploys an agent image to the agent's service, nothing else"
  assume_role_policy = local.ecs_tasks_assume_role_policy
  tags               = var.tags
}

resource "aws_iam_role_policy" "updater_deploy_agent" {
  count = local.updater ? 1 : 0

  name = "deploy-${local.prefix}-agent"
  role = aws_iam_role.updater_task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadAgentService"
        Effect   = "Allow"
        Action   = "ecs:DescribeServices"
        Resource = aws_ecs_service.this.id
      },
      {
        # ECS does not scope DescribeTaskDefinition to a resource: it is "*"
        # or nothing. It reads a definition; it changes nothing.
        Sid      = "ReadTaskDefinitions"
        Effect   = "Allow"
        Action   = "ecs:DescribeTaskDefinition"
        Resource = "*"
      },
      {
        Sid      = "RegisterAgentTaskDefinition"
        Effect   = "Allow"
        Action   = "ecs:RegisterTaskDefinition"
        Resource = local.agent_task_family_arn
      },
      {
        # Only the agent's service, and only to a revision of the agent's own
        # family: never to another family's task definition and its roles.
        Sid      = "DeployAgentService"
        Effect   = "Allow"
        Action   = "ecs:UpdateService"
        Resource = aws_ecs_service.this.id
        Condition = {
          ArnLike = { "ecs:task-definition" = local.agent_task_family_arn }
        }
      },
      {
        # A new revision carries the agent's task and execution roles, and
        # registering it passes both. Exactly those two, and only to ECS.
        Sid    = "PassAgentRoles"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.task.arn,
          aws_iam_role.execution.arn,
        ]
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      },
    ]
  })
}

# The smallest Fargate task, on ARM like the agent. The updater keeps no
# state: each update is a job Elastio hands it.

resource "aws_ecs_task_definition" "updater" {
  count = local.updater ? 1 : 0

  family                   = local.updater_ecs_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.updater_execution[0].arn
  task_role_arn            = aws_iam_role.updater_task[0].arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([local.updater_container])

  tags = var.tags
}

# One updater, and never two: two would take the same update job. Minimum
# healthy 0 / maximum 100 stops the old task before starting the new one, as
# for the agent. Same subnets and security groups as the agent: it needs
# outbound HTTPS to Elastio, the registry and the ECS API, and no inbound.

resource "aws_ecs_service" "updater" {
  count = local.updater ? 1 : 0

  name            = local.updater_ecs_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.updater[0].arn
  launch_type     = "FARGATE"
  desired_count   = 1

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  enable_execute_command = false

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  tags = var.tags

  # As for the agent: the task must not start before it may read its secret
  # and deploy, and destroy must not remove the permissions under it.
  depends_on = [
    aws_iam_role_policy_attachment.updater_execution,
    aws_iam_role_policy.updater_read_api_key,
    aws_iam_role_policy.updater_deploy_agent,
    aws_secretsmanager_secret_version.api_key,
  ]
}
