# `elastio-database-monitoring-agent` module

This Terraform module runs the Elastio database monitoring agent on AWS Fargate. One agent watches one PostgreSQL database and reports to your Elastio tenant.

## Installation

Elastio terraform modules are published to the public Cloudsmith registry. Before you add this module, add this to your [`.terraformrc`](https://developer.hashicorp.com/terraform/cli/config/config-file). The file lives in your home directory (if you are on Linux):

```hcl
credentials "terraform.cloudsmith.io" {
  token = "elastio/public/"
}
```

Then add the module to your project:

```tf
module "elastio_database_monitoring_agent" {
  source  = "terraform.cloudsmith.io/public/elastio-database-monitoring-agent/aws"
  version = "0.1.0"

  name         = "orders-db-prod"
  server_url   = "https://<your tenant>.app.elastio.com"
  api_key      = var.elastio_api_key # shown by the Elastio Portal when you add the database
  database_url = var.database_url    # postgres://user:pass@host:5432/dbname

  subnet_ids         = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]
  security_group_ids = ["sg-0123456789abcdef0"]
}
```

You can find the full version of this example in [`examples/basic`](./examples/basic).

The `image` input defaults to the agent release this module version was tested with. Leave it unset unless Elastio support asks you to pin a different one.

Pass `api_key` and `database_url` as sensitive variables or from your own secret store. They are stored in two Secrets Manager secrets that the module creates, and ECS reads them when the task starts. They never appear in the task definition. The module also generates a third secret, a random key for the agent.

## Prerequisites

**Run the setup SQL first.** The Elastio Portal shows the exact statements for your database when you add it: a role with `REPLICATION`, a publication, and a replication slot that uses the `pgoutput` plugin. The agent never creates or drops a slot or a publication. It attaches to ones that already exist. If the slot is missing when the task starts, the agent exits and ECS keeps restarting it until the slot exists.

**The subnets must reach both the database and the internet.** The agent connects to the database on its port, and to your Elastio tenant over HTTPS. Private subnets need a NAT gateway for the second connection. If they have none, set `assign_public_ip = true` and use subnets that have a route to an internet gateway. The subnets must exist before you run `terraform plan`, because the module reads each subnet's availability zone to decide where to put the EFS mount targets.

**The security groups need these outbound rules:**

- the database port, to the database;
- TCP 443, to your Elastio tenant;
- TCP 2049, to the VPC, for NFS to the agent's EFS file system (only needed with the default `persistent_ledger = true`).

A security group with the usual allow-all egress already allows all three. The database's own security group must allow inbound traffic from these security groups on the database port.

## What it creates

- An ECS cluster, service and task family named after `name` (with any characters ECS doesn't allow replaced), with Container Insights turned off.
- A CloudWatch log group named `/elastio-dbmon/agent/<name>`.
- Three Secrets Manager secrets, `elastio-dbmon/<name>/api-key-*`, `.../database-url-*` and `.../hash-secret-*`. The third is a random key, 32 bytes hex-encoded, that must stay the same for the life of the agent's state. Never taint or replace it.
- IAM roles `elastio-dbmon-<name>-exec-*` and `elastio-dbmon-<name>-task-*`. The execution role has `AmazonECSTaskExecutionRolePolicy` and permission to read exactly those three secrets. The agent makes no AWS calls, so the task role carries only the EFS mount permission below.
- With `persistent_ledger = true` (the default), storage so the agent's state persists across task replacement:
  - an encrypted EFS file system tagged `elastio-dbmon-<name>-ledger`, using General Purpose performance mode and bursting throughput;
  - one mount target per distinct availability zone among `subnet_ids`;
  - a security group `elastio-dbmon-<name>-efs-*` on the mount targets, which allows TCP 2049 only from `security_group_ids`;
  - an access point that maps every client to uid/gid 65532 and roots it at `/elastio-dbmon`, created with mode 0700;
  - a task-role policy that allows `elasticfilesystem:ClientMount` and `ClientWrite` on the file system, only through that access point.
  - a file system policy that refuses anonymous clients and denies every mount that does not use that access point or TLS. Other roles in the account with their own EFS permissions can still mount through the access point if the network admits them, so keep `security_group_ids` for the agent only.
- A Fargate task definition of `task_cpu` and `task_memory` (by default 0.25 vCPU and 0.5 GB), ARM64, with a read-only root filesystem. The task runs as the image's non-root user, with `GOMEMLIMIT` set to 80% of `task_memory`.
- A service with `desired_count = 1`. Its deployment policy (minimum healthy 0%, maximum 100%) stops the old task before it starts the new one. A replication slot allows only one consumer at a time, and the agent's state allows only one writer. Don't raise the maximum.

## Sizing

The default size, 0.25 vCPU and 512 MiB, is enough for one database's ordinary traffic. A larger task handles larger single transactions. A transaction larger than the task can handle doesn't stop the agent.

**The Elastio UI tells you when to size up.** When a transaction was too large for the task, the database shows an "oversized transaction" observation with the smallest task memory that would have handled it. Set `task_memory` to that value or higher, with a `task_cpu` that allows it, and apply.

| Size            | `task_cpu` | `task_memory` | `GOMEMLIMIT` | Largest transaction, about                   | Per month, us-east-1 |
| --------------- | ---------- | ------------- | ------------ | -------------------------------------------- | -------------------- |
| small (default) | 256        | 512           | 409 MiB      | 275,000 rows deleted or 170,000 inserted     | $7.21                |
| medium          | 512        | 1024          | 819 MiB      | 550,000 deleted or 340,000 inserted          | $14.42               |
| large           | 1024       | 2048          | 1638 MiB     | 1.1 million deleted or 680,000 inserted      | $28.84               |
| xlarge          | 2048       | 4096          | 3276 MiB     | 2.2 million deleted or 1.36 million inserted | $57.67               |

The transaction sizes are approximate and vary with table shape. Fargate also accepts other pairs, and the module accepts any pair that Fargate runs on ARM64:

| `task_cpu`      | `task_memory` (MiB)             |
| --------------- | ------------------------------- |
| 256 (0.25 vCPU) | 512, 1024, 2048                 |
| 512 (0.5 vCPU)  | 1024 to 4096, in steps of 1024  |
| 1024 (1 vCPU)   | 2048 to 8192, in steps of 1024  |
| 2048 (2 vCPU)   | 4096 to 16384, in steps of 1024 |

A different size replaces the task. The agent's state is on EFS, so nothing is lost, and the replication slot keeps the write-ahead log for the minute or so that no task is running.

## Cost

In us-east-1 at on-demand rates, ARM Fargate costs $0.03238 per vCPU-hour and $0.00356 per GB-hour. The default size costs:

|           | rate                   | per month (730 h) |
| --------- | ---------------------- | ----------------- |
| 0.25 vCPU | $0.03238 per vCPU-hour | $5.91             |
| 0.5 GB    | $0.00356 per GB-hour   | $1.30             |
|           |                        | **$7.21**         |

The other sizes are in the Sizing table above. On top of the task:

- **Secrets Manager:** three secrets at $0.40 each, so $1.20 a month.
- **EFS:** the agent's state stays at tens of MB, which is cents a month. Mount targets and access points are free.
- **Ephemeral storage and CloudWatch:** the extra GB of ephemeral storage above the free 20 GB, and CloudWatch log ingestion, each cost a few cents.

If the subnets use a NAT gateway, its hourly charge will be your largest cost by far. You pay that charge whether or not you deploy this module.

## Operating it

The agent writes its log to the log group above. `enable_execute_command` is off.

The agent's state is on EFS, so it persists across task replacement. With `persistent_ledger = false`, the state is on the task's ephemeral storage and every replacement starts it empty. Nothing is lost on the Elastio side.

## Upgrading

To upgrade the agent, bump the module `version` and apply. A new version replaces the task; the agent's state is on EFS, so nothing is lost.

## Removing

To remove the agent, run `terraform destroy`, then **drop the replication slot** in the database. An abandoned slot keeps write-ahead log until the disk fills.

## Testing the module

`tests/module.tftest.hcl` plans the module against mocked providers, so it needs no AWS account:

```sh
terraform init -backend=false && terraform test
```

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                     | Version |
| ------------------------------------------------------------------------ | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | ~> 1.9  |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                   | >= 5.0  |
| <a name="requirement_random"></a> [random](#requirement_random)          | >= 3.0  |

## Providers

| Name                                                      | Version |
| --------------------------------------------------------- | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws)          | >= 5.0  |
| <a name="provider_random"></a> [random](#provider_random) | >= 3.0  |

## Modules

No modules.

## Resources

| Name                                                                                                                                                              | Type        |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                                 | resource    |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster)                                                   | resource    |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)                                                   | resource    |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)                                   | resource    |
| [aws_efs_access_point.ledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point)                                       | resource    |
| [aws_efs_file_system.ledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system)                                         | resource    |
| [aws_efs_file_system_policy.ledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system_policy)                           | resource    |
| [aws_efs_mount_target.ledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target)                                       | resource    |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                    | resource    |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                         | resource    |
| [aws_iam_role_policy.mount_ledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                                   | resource    |
| [aws_iam_role_policy.read_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                                   | resource    |
| [aws_iam_role_policy_attachment.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)                | resource    |
| [aws_secretsmanager_secret.api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                            | resource    |
| [aws_secretsmanager_secret.database_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                       | resource    |
| [aws_secretsmanager_secret.hash_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                        | resource    |
| [aws_secretsmanager_secret_version.api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)            | resource    |
| [aws_secretsmanager_secret_version.database_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)       | resource    |
| [aws_secretsmanager_secret_version.hash_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)        | resource    |
| [aws_security_group.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                              | resource    |
| [aws_vpc_security_group_ingress_rule.efs_from_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource    |
| [random_id.hash_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id)                                                        | resource    |
| [aws_subnet.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet)                                                          | data source |

## Inputs

| Name                                                                                    | Description                                                                                                                                                                                                                                                                       | Type           | Default                                                            | Required |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------------------------------------ | :------: |
| <a name="input_api_key"></a> [api_key](#input_api_key)                                  | Bearer token the agent presents to the server. Stored in Secrets Manager, never in the task definition.                                                                                                                                                                           | `string`       | n/a                                                                |   yes    |
| <a name="input_assign_public_ip"></a> [assign_public_ip](#input_assign_public_ip)       | Give the task a public IP. Needed only when the subnets have no NAT gateway and the server URL is on the internet.                                                                                                                                                                | `bool`         | `false`                                                            |    no    |
| <a name="input_database_url"></a> [database_url](#input_database_url)                   | postgres:// URL of the database to watch, for a role with REPLICATION. Stored in Secrets Manager, never in the task definition.                                                                                                                                                   | `string`       | n/a                                                                |   yes    |
| <a name="input_image"></a> [image](#input_image)                                        | Agent image. The default is the agent release this module version was tested with. Pin a version; :latest moves. Needs 0.1.5 or later: older agents read only the QUELL\_\* variable names.                                                                                       | `string`       | `"public.ecr.aws/elastio/elastio-database-monitoring-agent:0.1.6"` |    no    |
| <a name="input_log_retention_days"></a> [log_retention_days](#input_log_retention_days) | How long CloudWatch keeps the agent's log.                                                                                                                                                                                                                                        | `number`       | `7`                                                                |    no    |
| <a name="input_name"></a> [name](#input_name)                                           | What the product shows for this agent. Also the ECS cluster, service and task family name, sanitised to the characters ECS allows.                                                                                                                                                | `string`       | n/a                                                                |   yes    |
| <a name="input_persistent_ledger"></a> [persistent_ledger](#input_persistent_ledger)    | Keep the agent's state on an encrypted EFS file system so it persists across task replacement. When false, the state is on the task's ephemeral storage and every replacement starts it empty.                                                                                    | `bool`         | `true`                                                             |    no    |
| <a name="input_publication"></a> [publication](#input_publication)                      | Name of the publication whose tables are streamed.                                                                                                                                                                                                                                | `string`       | `"elastio_monitor"`                                                |    no    |
| <a name="input_security_group_ids"></a> [security_group_ids](#input_security_group_ids) | Security groups attached to the task. The database's own security group must admit them on its port.                                                                                                                                                                              | `list(string)` | n/a                                                                |   yes    |
| <a name="input_server_url"></a> [server_url](#input_server_url)                         | Base URL of the server the agent reports to.                                                                                                                                                                                                                                      | `string`       | n/a                                                                |   yes    |
| <a name="input_slot"></a> [slot](#input_slot)                                           | Name of the existing pgoutput replication slot. The agent never creates or drops one.                                                                                                                                                                                             | `string`       | `"elastio_monitor"`                                                |    no    |
| <a name="input_subnet_ids"></a> [subnet_ids](#input_subnet_ids)                         | Subnets the task runs in. They must reach the database and the server URL.                                                                                                                                                                                                        | `list(string)` | n/a                                                                |   yes    |
| <a name="input_tags"></a> [tags](#input_tags)                                           | Tags applied to every resource the module creates.                                                                                                                                                                                                                                | `map(string)`  | `{}`                                                               |    no    |
| <a name="input_task_cpu"></a> [task_cpu](#input_task_cpu)                               | CPU units for the Fargate task: 256 (0.25 vCPU), 512, 1024 or 2048. Together with task_memory it must be a size Fargate runs on ARM64; see Sizing in the README.                                                                                                                  | `number`       | `256`                                                              |    no    |
| <a name="input_task_memory"></a> [task_memory](#input_task_memory)                      | Memory for the Fargate task, in MiB. With task_cpu 256: 512, 1024 or 2048. With 512: 1024 to 4096. With 1024: 2048 to 8192. With 2048: 4096 to 16384. Above 512, in steps of 1024. The agent's Go memory limit follows it. Raise it when the Elastio UI recommends a larger size. | `number`       | `512`                                                              |    no    |

## Outputs

| Name                                                                                               | Description                                                                                                                                          |
| -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="output_cluster_arn"></a> [cluster_arn](#output_cluster_arn)                               | ARN of the ECS cluster the agent runs in.                                                                                                            |
| <a name="output_execution_role_arn"></a> [execution_role_arn](#output_execution_role_arn)          | IAM role ECS uses to pull the image, read the three secrets and write logs.                                                                          |
| <a name="output_hash_secret_arn"></a> [hash_secret_arn](#output_hash_secret_arn)                   | ARN of the Secrets Manager secret holding the agent's key. It must stay stable for the life of the agent's state.                                    |
| <a name="output_ledger_file_system_id"></a> [ledger_file_system_id](#output_ledger_file_system_id) | ID of the EFS file system holding the agent's state, or null when persistent_ledger is false.                                                        |
| <a name="output_log_group_name"></a> [log_group_name](#output_log_group_name)                      | CloudWatch log group the agent writes to.                                                                                                            |
| <a name="output_service_name"></a> [service_name](#output_service_name)                            | Name of the ECS service.                                                                                                                             |
| <a name="output_task_role_arn"></a> [task_role_arn](#output_task_role_arn)                         | IAM role the running container assumes. The agent has no AWS code; with persistent state the role may mount the state file system, and nothing else. |

<!-- END_TF_DOCS -->
