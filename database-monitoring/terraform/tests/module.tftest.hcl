# Offline checks of what the module plans, with mocked providers: no AWS
# account or credentials needed. Run from this directory with
#   terraform init -backend=false && terraform test

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

# Two subnets in one AZ share a mount target; a third in another AZ gets its own.
run "one_mount_target_per_az" {
  command = apply

  variables {
    subnet_ids = ["subnet-a", "subnet-b", "subnet-c"]
  }

  override_data {
    target = data.aws_subnet.this["subnet-c"]
    values = { availability_zone = "us-east-1b", vpc_id = "vpc-1" }
  }

  assert {
    condition     = length(aws_efs_mount_target.ledger) == 2
    error_message = "expected one mount target per distinct AZ"
  }
}

run "same_az_two_subnets" {
  command = apply
  assert {
    condition     = length(aws_efs_mount_target.ledger) == 1
    error_message = "two subnets in one AZ must share a mount target"
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.efs_from_agent) == 2
    error_message = "one ingress rule per task SG"
  }
  assert {
    condition     = one(aws_ecs_task_definition.this.volume).efs_volume_configuration[0].transit_encryption == "ENABLED"
    error_message = "the ledger volume must be EFS with transit encryption"
  }
  assert {
    condition     = strcontains(aws_ecs_task_definition.this.container_definitions, "\"awslogs-region\":\"us-east-1\"")
    error_message = "the log driver must be given the module's region"
  }
  assert {
    condition     = strcontains(aws_ecs_task_definition.this.container_definitions, "ELASTIO_DBMON_HASH_SECRET")
    error_message = "ELASTIO_DBMON_HASH_SECRET must reach the container"
  }
  assert {
    condition     = !strcontains(aws_ecs_task_definition.this.container_definitions, "QUELL_")
    error_message = "the agent is configured by the ELASTIO_DBMON_* names, not the old QUELL_* ones"
  }
  assert {
    condition     = strcontains(aws_ecs_task_definition.this.container_definitions, "\"name\":\"GOMEMLIMIT\",\"value\":\"409MiB\"")
    error_message = "the Go memory limit must be 80% of the 512 MiB task"
  }
  assert {
    condition     = strcontains(aws_ecs_task_definition.this.container_definitions, "\"containerPath\":\"/var/lib/elastio-dbmon\"") && strcontains(aws_ecs_task_definition.this.container_definitions, "\"value\":\"/var/lib/elastio-dbmon/ledger\"")
    error_message = "the ledger must be mounted where the agent image keeps it, and named explicitly"
  }
  assert {
    condition     = aws_ecs_service.this.deployment_maximum_percent == 100 && aws_ecs_service.this.deployment_minimum_healthy_percent == 0
    error_message = "two tasks must never run against one ledger"
  }
  assert {
    condition     = jsondecode(aws_efs_file_system_policy.ledger[0].policy).Statement[0].Condition.StringEquals["elasticfilesystem:AccessPointArn"] == aws_efs_access_point.ledger[0].arn
    error_message = "the file system policy must admit the task only through the access point"
  }
  assert {
    condition     = toset([for st in jsondecode(aws_efs_file_system_policy.ledger[0].policy).Statement : st.Sid if st.Effect == "Deny"]) == toset(["DenyOtherPrincipals", "DenyWithoutAccessPoint", "DenyInsecureTransport"])
    error_message = "the file system policy must deny other principals, access without the access point, and access without TLS"
  }
}

run "rejects_empty_network" {
  command = plan

  variables {
    subnet_ids         = []
    security_group_ids = []
  }

  expect_failures = [var.subnet_ids, var.security_group_ids]
}

run "names_and_image" {
  command = plan

  variables {
    name = "a-very-long-agent-name-for-the-orders-database"
  }

  assert {
    condition     = startswith(aws_iam_role.execution.name_prefix, "elastio-dbmon-") && length(aws_iam_role.execution.name_prefix) <= 38
    error_message = "the execution role prefix must be elastio-dbmon- and fit IAM's 38-character name_prefix limit"
  }
  assert {
    condition     = length(aws_iam_role.task.name_prefix) <= 38
    error_message = "the task role prefix must fit IAM's 38-character name_prefix limit"
  }
  assert {
    condition     = aws_cloudwatch_log_group.this.name == "/elastio-dbmon/agent/a-very-long-agent-name-for-the-orders-database"
    error_message = "unexpected log group name"
  }
  assert {
    condition     = startswith(aws_secretsmanager_secret.api_key.name_prefix, "elastio-dbmon/")
    error_message = "secrets must be named elastio-dbmon/<name>/..."
  }
  assert {
    condition     = strcontains(aws_ecs_task_definition.this.container_definitions, "public.ecr.aws/elastio/elastio-database-monitoring-agent:")
    error_message = "the default image must be Elastio's public ECR image"
  }
}

run "ephemeral" {
  command = apply
  variables {
    persistent_ledger = false
  }
  assert {
    condition     = length(aws_efs_file_system.ledger) == 0 && length(aws_efs_mount_target.ledger) == 0 && length(aws_security_group.efs) == 0 && length(aws_efs_file_system_policy.ledger) == 0
    error_message = "persistent_ledger = false must create no EFS resources"
  }
  assert {
    condition     = length(one(aws_ecs_task_definition.this.volume).efs_volume_configuration) == 0
    error_message = "persistent_ledger = false must keep the ephemeral bind mount"
  }
  assert {
    condition     = output.ledger_file_system_id == null
    error_message = "ledger_file_system_id must be null without EFS"
  }
}
