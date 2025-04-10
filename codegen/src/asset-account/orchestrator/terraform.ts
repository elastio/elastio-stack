import type { Resource } from "../mir";
import _ from "lodash";
import * as hclTools from "@cdktf/hcl-tools";
import * as iam from "../../common/iam";
import * as prettier from "prettier";

async function literal(value: unknown): Promise<string> {
  const json = JSON.stringify(value, null, 2);
  const pretty = await prettier.format(json, { parser: "json" });
  return pretty.trim();
}

async function jsonencode(value: unknown): Promise<string> {
  return `jsonencode(\n${await literal(value)}\n)`;
}

function policyDocument(statements: iam.PolicyStatement[]) {
  return {
    Version: "2012-10-17",
    Statement: statements.map((statement) => ({
      ...statement,
      Effect: statement.Effect ?? "Allow",
    })),
  };
}

export async function generate(resources: Record<string, Resource>) {
  const parts = [];

  for (const [id, resource] of Object.entries(resources)) {
    switch (resource.type) {
      case "aws_iam_role": {
        parts.push(
          `resource "aws_iam_role" "${id}" {
            name = "${resource.name}"
            assume_role_policy = ${await jsonencode(policyDocument([resource.assumeRolePolicy]))}
          }`,
        );

        const statements = Object.entries(resource.statements);

        if (statements.length === 0) {
          continue;
        }

        const policies = _.mapValues(
          resource.statements,
          (statement) => policyDocument(statement).Statement,
        );

        parts.push(
          `resource "aws_iam_role_policy" "${id}" {
            role = aws_iam_role.${id}.name
            name = each.key
            policy = jsonencode(
              {
                "Version": "2012-10-17",
                "Statement": each.value
              }
            )
            for_each = ${await literal(policies)}
          }`,
        );
      }
      case "aws_ssm_parameter": {
      }
    }
  }

  parts.push(`
    data "aws_caller_identity" "current" {}
    locals {
      account_id = data.aws_caller_identity.current.account_id
    }
  `);

  const content = parts
    .join("\n\n")
    .replaceAll("{{account_id}}", "${local.account_id}")
    .replaceAll(/\{\{(.*)\}\}/g, "${$1}");

  console.log(await hclTools.format(content));
}

function camelCaseToSnakeCase(str: string): string {
  return str.replace(/([a-z])([A-Z])/g, "$1_$2").toLowerCase();
}
