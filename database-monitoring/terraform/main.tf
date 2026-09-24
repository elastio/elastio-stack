# One Elastio database monitoring agent on AWS Fargate, watching one database.
#
# The agent is a single static binary that needs a network path to the
# database and to the server URL, three secrets, and a small writable directory
# for its ledger that outlives the task. Everything below is the least that
# gives it those.

locals {
  # ECS names allow letters, digits, hyphens and underscores, up to 255. The
  # product-facing name is passed to the agent untouched as
  # ELASTIO_DBMON_AGENT_NAME.
  ecs_name = substr(replace(var.name, "/[^A-Za-z0-9_-]/", "-"), 0, 255)

  # A shortened form for name prefixes with tight length limits. An IAM role
  # name_prefix is at most 38 characters: "elastio-dbmon-" (14) + 16 +
  # "-exec-" (6) = 36.
  short_name = substr(local.ecs_name, 0, 16)

  # All resource names start with this.
  prefix = "elastio-dbmon"

  # distroless nonroot, and what the image's USER resolves to.
  uid = 65532
  gid = 65532

  # The ledger directory inside the container. It is the agent image's own
  # writable volume (owned by the nonroot user) from 0.1.5, and the binary's
  # default ledger path is beneath it. Only the mount point moves with it:
  # the EFS access point's contents, the ledger and nothing else, are the
  # same file under either path, because the path is also passed explicitly.
  ledger_dir = "/var/lib/elastio-dbmon"

  # Task size. The default is the Fargate floor: one agent reads one
  # database's stream and needs no more for ordinary traffic (measured in
  # elastio/database-monitoring-agent bench/). What a larger task buys is the
  # size of the largest transaction the agent holds whole; past that it
  # judges the transaction from its row counts and says so. See Sizing in the
  # README.
  task_cpu    = var.task_cpu
  task_memory = var.task_memory

  # The Go runtime's soft memory limit, 80% of the task, and so the budget
  # for one open transaction (30% of this). Go does not derive one from the
  # container on its own, and without it a heap whose live size is half the
  # task is allowed to double before it is collected. The agent derives the
  # same number itself when this is unset (from 0.1.6 through the ECS task
  # metadata, because a Fargate task's limit is on the task and the
  # container's cgroup reads "max"); it is set here so the number in force
  # is visible in the task definition.
  gomemlimit = "${floor(local.task_memory * 0.8)}MiB"
}

resource "aws_ecs_cluster" "this" {
  name = local.ecs_name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/${local.prefix}/agent/${local.ecs_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

locals {
  # The region the module deploys into, read from an ARN rather than from
  # `data.aws_region`, whose name/id attributes are deprecated in AWS provider
  # 6 but are the only ones in 5.
  region = split(":", aws_cloudwatch_log_group.this.arn)[3]
}

# The three secrets. They reach the container through the task definition's
# `secrets` block, which the execution role resolves at launch; the values
# never appear in the task definition or in `aws ecs describe-tasks`.

resource "aws_secretsmanager_secret" "api_key" {
  name_prefix = "${local.prefix}/${local.ecs_name}/api-key-"
  description = "API key the Elastio database monitoring agent presents to the Elastio server"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = var.api_key
}

resource "aws_secretsmanager_secret" "database_url" {
  name_prefix = "${local.prefix}/${local.ecs_name}/database-url-"
  description = "Connection URL of the database the Elastio database monitoring agent watches"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = var.database_url
}

# The agent's hashing key, used to minimise evidence before it leaves the
# database's network. Without it the agent generates one and keeps it beside
# the ledger, so a lost ledger took the key with it. Here the key is generated
# once, by Terraform, and outlives every task. It must stay stable for the
# life of the ledger: evidence minimised under a different key cannot be
# compared with what the ledger holds, and redelivered transactions would be
# refused as conflicting. So never taint or replace it while a ledger exists.
# 32 random bytes, hex-encoded: 64 characters, the same shape the agent
# generates for itself.

resource "random_id" "hash_secret" {
  byte_length = 32
}

resource "aws_secretsmanager_secret" "hash_secret" {
  name_prefix = "${local.prefix}/${local.ecs_name}/hash-secret-"
  description = "Hashing key of the Elastio database monitoring agent. Must stay stable for the life of the agent's ledger"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "hash_secret" {
  secret_id     = aws_secretsmanager_secret.hash_secret.id
  secret_string = random_id.hash_secret.hex
}

# Roles. The execution role is ECS's own: pull the image, read the secrets,
# write logs. The task role is what the process would assume if it called
# AWS, and it never does. With a persistent ledger it is also the identity the
# EFS mount helper presents, and carries exactly the permission to mount and
# write the file system through the module's access point.

locals {
  ecs_tasks_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      },
    ]
  })
}

resource "aws_iam_role" "execution" {
  name_prefix        = "${local.prefix}-${local.short_name}-exec-"
  description        = "ECS task execution role of the Elastio database monitoring agent"
  assume_role_policy = local.ecs_tasks_assume_role_policy
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "read_secrets" {
  name = "read-${local.prefix}-secrets"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "secretsmanager:GetSecretValue"
        Resource = [
          aws_secretsmanager_secret.api_key.arn,
          aws_secretsmanager_secret.database_url.arn,
          aws_secretsmanager_secret.hash_secret.arn,
        ]
      },
    ]
  })
}

resource "aws_iam_role" "task" {
  name_prefix        = "${local.prefix}-${local.short_name}-task-"
  description        = "ECS task role of the Elastio database monitoring agent"
  assume_role_policy = local.ecs_tasks_assume_role_policy
  tags               = var.tags
}

# The ledger's storage. The agent's review re-reads a standing finding's
# original window from the ledger to decide whether later activity explains
# it; a ledger that starts empty after a task replacement has lost that
# window, and the finding can then never be explained. Task replacements are
# routine (a deploy, a forced new deployment, a crash, Fargate's own platform
# maintenance), so by default the ledger lives on EFS and survives them.
#
# One mount target per distinct availability zone among the subnets: EFS
# admits one per AZ, and two subnets in the same AZ share it.

data "aws_subnet" "this" {
  for_each = var.persistent_ledger ? toset(var.subnet_ids) : toset([])
  id       = each.value
}

locals {
  # AZ => the subnets in it, and one subnet per AZ for the mount target.
  subnets_by_az        = { for id, s in data.aws_subnet.this : s.availability_zone => id... }
  mount_target_subnets = { for az, ids in local.subnets_by_az : az => sort(ids)[0] }
  vpc_id               = var.persistent_ledger ? data.aws_subnet.this[var.subnet_ids[0]].vpc_id : null
}

resource "aws_efs_file_system" "ledger" {
  count = var.persistent_ledger ? 1 : 0

  # No creation_token: the provider generates a unique one. A token derived
  # from `name` would exceed EFS's 64-character limit for long names.
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(var.tags, { Name = "${local.prefix}-${local.ecs_name}-ledger" })
}

resource "aws_security_group" "efs" {
  count = var.persistent_ledger ? 1 : 0

  name_prefix = "${local.prefix}-${local.short_name}-efs-"
  description = "NFS to the Elastio database monitoring agent ledger, from the agent security groups only"
  vpc_id      = local.vpc_id

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs_from_agent" {
  # count, not for_each, so security groups created in the same apply work.
  count = var.persistent_ledger ? length(var.security_group_ids) : 0

  security_group_id            = aws_security_group.efs[0].id
  referenced_security_group_id = var.security_group_ids[count.index]
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "NFS from the Elastio database monitoring agent task"
  tags                         = var.tags
}

resource "aws_efs_mount_target" "ledger" {
  for_each = var.persistent_ledger ? local.mount_target_subnets : {}

  file_system_id  = aws_efs_file_system.ledger[0].id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs[0].id]
}

# The access point pins every client to uid/gid 65532 and roots it at
# /elastio-dbmon, created 0700 for that uid, so the agent sees a private
# directory it owns and nothing else on the file system.

resource "aws_efs_access_point" "ledger" {
  count = var.persistent_ledger ? 1 : 0

  file_system_id = aws_efs_file_system.ledger[0].id

  posix_user {
    uid = local.uid
    gid = local.gid
  }

  root_directory {
    path = "/${local.prefix}"

    creation_info {
      owner_uid   = local.uid
      owner_gid   = local.gid
      permissions = "0700"
    }
  }

  tags = var.tags
}

resource "aws_iam_role_policy" "mount_ledger" {
  count = var.persistent_ledger ? 1 : 0

  name = "mount-${local.prefix}-ledger"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
        ]
        Resource = aws_efs_file_system.ledger[0].arn
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" = aws_efs_access_point.ledger[0].arn
          }
        }
      },
    ]
  })
}

# Without a file system policy, EFS lets any NFS client that reaches a mount
# target mount it as root. With this policy, anonymous clients are refused,
# and every client must use TLS and the module's access point. EFS enforces
# only a few condition keys for NFS clients, and none identifies the caller,
# so another role in the account with its own EFS client permissions can
# still mount through the access point if the network admits it. The EFS
# security group, which admits only `security_group_ids`, is that boundary.

resource "aws_efs_file_system_policy" "ledger" {
  count = var.persistent_ledger ? 1 : 0

  file_system_id = aws_efs_file_system.ledger[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AgentThroughAccessPoint"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.task.arn }
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
        ]
        Resource = aws_efs_file_system.ledger[0].arn
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" = aws_efs_access_point.ledger[0].arn
          }
        }
      },
      {
        Sid       = "DenyWithoutAccessPoint"
        Effect    = "Deny"
        Principal = { AWS = "*" }
        Action    = "elasticfilesystem:Client*"
        Resource  = aws_efs_file_system.ledger[0].arn
        Condition = {
          StringNotEquals = {
            "elasticfilesystem:AccessPointArn" = aws_efs_access_point.ledger[0].arn
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = { AWS = "*" }
        Action    = "*"
        Resource  = aws_efs_file_system.ledger[0].arn
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })
}

# The task. The smallest Fargate size, on ARM because it is the cheaper of
# the two and the image is published for both. The root filesystem is
# read-only; the ledger directory is the EFS access point above, or, with
# persistent_ledger = false, a bind mount onto the task's ephemeral storage,
# which Fargate creates writable for the container's uid.

resource "aws_ecs_task_definition" "this" {
  family                   = local.ecs_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.task_cpu
  memory                   = local.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  ephemeral_storage {
    size_in_gib = 21 # the Fargate minimum
  }

  volume {
    name = "ledger"

    dynamic "efs_volume_configuration" {
      for_each = var.persistent_ledger ? [1] : []

      content {
        file_system_id     = aws_efs_file_system.ledger[0].id
        transit_encryption = "ENABLED"

        authorization_config {
          access_point_id = aws_efs_access_point.ledger[0].id
          iam             = "ENABLED"
        }
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "${local.prefix}-agent"
      image     = var.image
      essential = true
      user      = "${local.uid}:${local.gid}"

      readonlyRootFilesystem = true

      mountPoints = [
        {
          sourceVolume  = "ledger"
          containerPath = local.ledger_dir
          readOnly      = false
        },
      ]

      # The ELASTIO_DBMON_* names are the agent binary's configuration
      # contract from 0.1.5. The agent still reads the QUELL_* names older
      # deployments set, but an image older than 0.1.5 reads only those, so
      # this module needs agent 0.1.5 or later.
      environment = [
        { name = "ELASTIO_DBMON_SERVER_URL", value = var.server_url },
        { name = "ELASTIO_DBMON_SLOT", value = var.slot },
        { name = "ELASTIO_DBMON_PUBLICATION", value = var.publication },
        { name = "ELASTIO_DBMON_AGENT_NAME", value = var.name },
        { name = "ELASTIO_DBMON_LEDGER_PATH", value = "${local.ledger_dir}/ledger" },
        { name = "GOMEMLIMIT", value = local.gomemlimit },
      ]

      secrets = [
        { name = "ELASTIO_DBMON_API_KEY", valueFrom = aws_secretsmanager_secret.api_key.arn },
        { name = "ELASTIO_DBMON_DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn },
        { name = "ELASTIO_DBMON_HASH_SECRET", valueFrom = aws_secretsmanager_secret.hash_secret.arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "agent"
        }
      }
    },
  ])

  tags = var.tags
}

# The service. Exactly one task, and never two: a replication slot admits one
# consumer, so a rolling deployment that starts the new task before stopping
# the old one would leave the new task failing to attach until the old one
# exits. Minimum healthy 0 / maximum 100 makes ECS stop the old task first.
# The gap is bounded by the slot: write-ahead log accumulates on the database
# while nobody reads it and is streamed when the new task attaches.
#
# With a persistent ledger this is also what keeps the ledger sound. The
# design is one process per ledger with no lease; two tasks writing the same
# EFS ledger during a rolling deployment would corrupt it. Never raise
# deployment_maximum_percent above 100.

resource "aws_ecs_service" "this" {
  name            = local.ecs_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
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

  # The task definition references the roles and secrets, but not their
  # policies or values. Without these, the first task can start before it may
  # read the secrets or mount the ledger, and destroy can remove the
  # permissions while the task still runs. A task also cannot mount the
  # ledger before a mount target exists in its AZ.
  depends_on = [
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy.read_secrets,
    aws_iam_role_policy.mount_ledger,
    aws_secretsmanager_secret_version.api_key,
    aws_secretsmanager_secret_version.database_url,
    aws_secretsmanager_secret_version.hash_secret,
    aws_efs_mount_target.ledger,
    aws_efs_file_system_policy.ledger,
  ]
}
