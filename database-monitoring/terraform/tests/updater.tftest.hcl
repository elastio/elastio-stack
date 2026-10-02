# Offline checks of the deployment updater, with mocked providers: no AWS
# account or credentials needed. Run from this directory with
#   terraform init -backend=false && terraform test
#
# A file of its own so that its apply starts from empty state: a run's
# override_resource only reaches resources that run creates, and the applies
# in module.tftest.hcl have already created the agent's.

mock_provider "aws" {
  mock_data "aws_subnet" {
    defaults = { availability_zone = "us-east-1a", vpc_id = "vpc-1" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:x" }
  }
  mock_resource "aws_efs_file_system" {
    defaults = { arn = "arn:aws:elasticfilesystem:us-east-1:123456789012:file-system/fs-1" }
  }
  mock_resource "aws_efs_access_point" {
    defaults = { arn = "arn:aws:elasticfilesystem:us-east-1:123456789012:access-point/fsap-1" }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:x" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/x" }
  }
}
mock_provider "random" {}

variables {
  name               = "orders db"
  server_url         = "https://x"
  api_key            = "k"
  database_url       = "postgres://x"
  subnet_ids         = ["subnet-a", "subnet-b"]
  security_group_ids = ["sg-1", "sg-2"]
}

# The deployment updater. Off by default: no second service, no roles.
run "updater_is_off_by_default" {
  command = plan

  assert {
    condition = (
      length(aws_ecs_service.updater) == 0 &&
      length(aws_ecs_task_definition.updater) == 0 &&
      length(aws_iam_role.updater_task) == 0 &&
      length(aws_iam_role.updater_execution) == 0 &&
      length(aws_iam_role_policy.updater_deploy_agent) == 0 &&
      length(aws_iam_role_policy.updater_read_api_key) == 0 &&
      length(aws_iam_role_policy_attachment.updater_execution) == 0
    )
    error_message = "updater must be opted into"
  }
  assert {
    condition     = output.updater_service_name == null && output.updater_task_role_arn == null
    error_message = "with the updater off, its outputs are null"
  }
}

# Without runtime_updates the next apply would undo what the updater deployed.
run "updater_requires_runtime_updates" {
  command = plan

  variables {
    updater = true
  }

  expect_failures = [var.updater]
}

# The updater cannot discover the agent's ID; without it the service would
# run, cost money and never update anything (review on #129).
run "updater_requires_agent_id" {
  command = plan

  variables {
    runtime_updates = true
    updater         = true
  }

  expect_failures = [var.agent_id]
}

run "updater_rejects_agent_id_that_is_not_a_uuid" {
  command = plan

  variables {
    runtime_updates = true
    updater         = true
    agent_id        = "orders-db"
  }

  expect_failures = [var.agent_id]
}

# With the updater off, agent_id stays optional.
run "agent_id_is_optional_without_the_updater" {
  command = plan

  variables {
    agent_id = "anything"
  }
}

run "rejects_unknown_update_channel" {
  command = plan

  variables {
    update_channel = "staging"
  }

  expect_failures = [var.update_channel]
}

# On: one more service, its own two roles, and a task role that can deploy
# to the agent's service and nothing else.
run "updater_deploys_only_the_agent" {
  command = apply

  variables {
    runtime_updates = true
    updater         = true
    agent_id        = "7d0c2b8e-3f1a-4e57-9a7c-1b2c3d4e5f60"
  }

  override_data {
    target = data.aws_ecs_service.runtime[0]
    values = { task_definition = "arn:aws:ecs:us-east-1:123456789012:task-definition/orders-db:7" }
  }
  override_data {
    target = data.aws_ecs_task_definition.runtime[0]
    values = { container_definitions = "[{\"name\":\"elastio-dbmon-agent\",\"image\":\"agent@sha256:new\"}]" }
  }
  override_resource {
    target = aws_ecs_service.this
    values = { id = "arn:aws:ecs:us-east-1:123456789012:service/orders-db/orders-db" }
  }
  override_resource {
    target = aws_ecs_task_definition.this
    values = {
      arn                  = "arn:aws:ecs:us-east-1:123456789012:task-definition/orders-db:8"
      arn_without_revision = "arn:aws:ecs:us-east-1:123456789012:task-definition/orders-db"
    }
  }
  override_resource {
    target = aws_iam_role.task
    values = { arn = "arn:aws:iam::123456789012:role/agent-task" }
  }
  override_resource {
    target = aws_iam_role.execution
    values = { arn = "arn:aws:iam::123456789012:role/agent-exec" }
  }
  override_resource {
    target = aws_iam_role.updater_task[0]
    values = { arn = "arn:aws:iam::123456789012:role/updater-task" }
  }
  override_resource {
    target = aws_iam_role.updater_execution[0]
    values = { arn = "arn:aws:iam::123456789012:role/updater-exec" }
  }
  override_resource {
    target = aws_secretsmanager_secret.api_key
    values = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:api-key" }
  }

  # Exactly one more service, task definition, two roles and their policies.
  assert {
    condition = (
      length(aws_ecs_service.updater) == 1 &&
      length(aws_ecs_task_definition.updater) == 1 &&
      length(aws_iam_role.updater_task) == 1 &&
      length(aws_iam_role.updater_execution) == 1 &&
      length(aws_iam_role_policy.updater_deploy_agent) == 1 &&
      length(aws_iam_role_policy.updater_read_api_key) == 1 &&
      length(aws_iam_role_policy_attachment.updater_execution) == 1
    )
    error_message = "updater = true must add one service with its own task definition, two roles and their policies"
  }
  assert {
    condition     = aws_ecs_service.updater[0].name == "orders-db-updater" && aws_ecs_service.updater[0].cluster == aws_ecs_cluster.this.id && aws_ecs_service.updater[0].desired_count == 1
    error_message = "the updater must be one task in the agent's cluster"
  }
  assert {
    condition     = aws_ecs_service.updater[0].deployment_maximum_percent == 100 && aws_ecs_service.updater[0].deployment_minimum_healthy_percent == 0
    error_message = "two updaters must never run at once: they would take the same job"
  }
  assert {
    condition     = toset(one(aws_ecs_service.updater[0].network_configuration).subnets) == toset(var.subnet_ids) && toset(one(aws_ecs_service.updater[0].network_configuration).security_groups) == toset(var.security_group_ids)
    error_message = "the updater must run in the agent's subnets and security groups"
  }
  assert {
    condition     = aws_ecs_task_definition.updater[0].cpu == "256" && aws_ecs_task_definition.updater[0].memory == "512" && one(aws_ecs_task_definition.updater[0].runtime_platform).cpu_architecture == "ARM64"
    error_message = "the updater is the smallest Fargate task, on ARM64"
  }
  assert {
    condition     = aws_ecs_task_definition.updater[0].task_role_arn == "arn:aws:iam::123456789012:role/updater-task" && aws_ecs_task_definition.updater[0].execution_role_arn == "arn:aws:iam::123456789012:role/updater-exec"
    error_message = "the updater must run with its own roles, never the agent's"
  }

  # Its container: configuration from the environment, the API key from the
  # agent's secret, the log in the module's log group.
  assert {
    condition = one(jsondecode(aws_ecs_task_definition.updater[0].container_definitions)).environment == [
      { name = "ELASTIO_DBMON_SERVER_URL", value = "https://x" },
      { name = "ELASTIO_DBMON_AGENT_ID", value = "7d0c2b8e-3f1a-4e57-9a7c-1b2c3d4e5f60" },
      { name = "ELASTIO_DBMON_DEPLOYMENT", value = "ecs" },
      { name = "ELASTIO_DBMON_UPDATE_CHANNEL", value = "production" },
      { name = "ELASTIO_DBMON_ECS_CLUSTER", value = "orders-db" },
      { name = "ELASTIO_DBMON_ECS_SERVICE", value = "orders-db" },
      { name = "ELASTIO_DBMON_ECS_CONTAINER", value = "elastio-dbmon-agent" },
    ]
    error_message = "the updater's environment must name the server, agent, channel and the agent's cluster, service and container"
  }
  assert {
    condition     = one(jsondecode(aws_ecs_task_definition.updater[0].container_definitions)).secrets == [{ name = "ELASTIO_DBMON_API_KEY", valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:api-key" }]
    error_message = "the updater's only secret is the agent's API key"
  }
  assert {
    condition     = one(jsondecode(aws_ecs_task_definition.updater[0].container_definitions)).image == "public.ecr.aws/elastio/elastio-database-monitoring-updater:0.1.10"
    error_message = "the production updater defaults to Elastio's public ECR image of this module's release"
  }
  assert {
    condition = one(jsondecode(aws_ecs_task_definition.updater[0].container_definitions)).logConfiguration.options == {
      "awslogs-group"         = aws_cloudwatch_log_group.this.name
      "awslogs-region"        = "us-east-1"
      "awslogs-stream-prefix" = "updater"
    }
    error_message = "the updater logs to the module's log group, under its own prefix"
  }

  # The execution role reads the API key and no other secret.
  assert {
    condition = jsondecode(aws_iam_role_policy.updater_read_api_key[0].policy) == {
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "secretsmanager:GetSecretValue"
          Resource = "arn:aws:secretsmanager:us-east-1:123456789012:secret:api-key"
        },
      ]
    }
    error_message = "the updater's execution role must read exactly the agent's API key"
  }
  assert {
    condition     = aws_iam_role_policy.updater_read_api_key[0].role == aws_iam_role.updater_execution[0].id && aws_iam_role_policy_attachment.updater_execution[0].role == aws_iam_role.updater_execution[0].name
    error_message = "the secret and execution policies belong to the updater's execution role"
  }

  # The task role, statement by statement.
  assert {
    condition = jsondecode(aws_iam_role_policy.updater_deploy_agent[0].policy) == {
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ReadAgentService"
          Effect   = "Allow"
          Action   = "ecs:DescribeServices"
          Resource = "arn:aws:ecs:us-east-1:123456789012:service/orders-db/orders-db"
        },
        {
          Sid      = "ReadTaskDefinitions"
          Effect   = "Allow"
          Action   = "ecs:DescribeTaskDefinition"
          Resource = "*"
        },
        {
          Sid      = "RegisterAgentTaskDefinition"
          Effect   = "Allow"
          Action   = "ecs:RegisterTaskDefinition"
          Resource = "arn:aws:ecs:us-east-1:123456789012:task-definition/orders-db:*"
        },
        {
          Sid       = "DeployAgentService"
          Effect    = "Allow"
          Action    = "ecs:UpdateService"
          Resource  = "arn:aws:ecs:us-east-1:123456789012:service/orders-db/orders-db"
          Condition = { ArnLike = { "ecs:task-definition" = "arn:aws:ecs:us-east-1:123456789012:task-definition/orders-db:*" } }
        },
        {
          Sid       = "PassAgentRoles"
          Effect    = "Allow"
          Action    = "iam:PassRole"
          Resource  = ["arn:aws:iam::123456789012:role/agent-task", "arn:aws:iam::123456789012:role/agent-exec"]
          Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } }
        },
      ]
    }
    error_message = "the updater's task role must be able to deploy to the agent's service and nothing else"
  }
  assert {
    condition     = aws_iam_role_policy.updater_deploy_agent[0].role == aws_iam_role.updater_task[0].id
    error_message = "the deploy policy belongs to the updater's task role"
  }
  # Stated separately, so a broadened PassRole fails with its own message.
  assert {
    condition = toset(flatten([
      for st in jsondecode(aws_iam_role_policy.updater_deploy_agent[0].policy).Statement : st.Resource
      if st.Action == "iam:PassRole"
    ])) == toset([aws_iam_role.task.arn, aws_iam_role.execution.arn])
    error_message = "iam:PassRole must be limited to the agent's task and execution roles"
  }
  assert {
    condition     = length(aws_iam_role.updater_task[0].name_prefix) <= 38 && length(aws_iam_role.updater_execution[0].name_prefix) <= 38
    error_message = "the updater's role prefixes must fit IAM's 38-character name_prefix limit"
  }
  assert {
    condition     = output.updater_service_name == "orders-db-updater" && output.updater_task_role_arn == "arn:aws:iam::123456789012:role/updater-task"
    error_message = "the updater's outputs name its service and task role"
  }
}

# On the development channel the updater says so, and defaults to the
# development image; an explicit image wins over either default.
run "updater_development_channel" {
  command = plan

  variables {
    runtime_updates = true
    updater         = true
    update_channel  = "development"
    agent_id        = "7d0c2b8e-3f1a-4e57-9a7c-1b2c3d4e5f60"
  }

  override_data {
    target = data.aws_ecs_service.runtime[0]
    values = { task_definition = "arn:aws:ecs:us-east-1:123456789012:task-definition/orders-db:7" }
  }
  override_data {
    target = data.aws_ecs_task_definition.runtime[0]
    values = { container_definitions = "[{\"name\":\"elastio-dbmon-agent\",\"image\":\"agent@sha256:new\"}]" }
  }

  assert {
    condition     = local.updater_container.image == "public.ecr.aws/elastio-development/elastio-database-monitoring-updater:latest"
    error_message = "the development updater defaults to the development image"
  }
  assert {
    condition     = contains(local.updater_container.environment, { name = "ELASTIO_DBMON_UPDATE_CHANNEL", value = "development" })
    error_message = "the updater must be told its channel"
  }
  assert {
    condition     = contains(local.updater_container.environment, { name = "ELASTIO_DBMON_AGENT_ID", value = "7d0c2b8e-3f1a-4e57-9a7c-1b2c3d4e5f60" })
    error_message = "the updater must be given the agent's ID"
  }
}

run "updater_image_override" {
  command = plan

  variables {
    runtime_updates = true
    updater         = true
    updater_image   = "example.com/mirror/updater@sha256:abc"
    agent_id        = "7d0c2b8e-3f1a-4e57-9a7c-1b2c3d4e5f60"
  }

  override_data {
    target = data.aws_ecs_service.runtime[0]
    values = { task_definition = "arn:aws:ecs:us-east-1:123456789012:task-definition/orders-db:7" }
  }
  override_data {
    target = data.aws_ecs_task_definition.runtime[0]
    values = { container_definitions = "[{\"name\":\"elastio-dbmon-agent\",\"image\":\"agent@sha256:new\"}]" }
  }

  assert {
    condition     = local.updater_container.image == "example.com/mirror/updater@sha256:abc"
    error_message = "an explicit updater_image must be used as given"
  }
}
