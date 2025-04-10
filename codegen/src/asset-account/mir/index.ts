import type { Resource } from "./resource";
import { Inputs } from "../inputs";
import { cloudConnectorRole } from "./cloud-connector";

export { Resource };

const version = "0.35.13";

export function resources(inputs: Inputs): Record<string, Resource> {
  return {
    inventory_event_target: {
      type: "aws_iam_role",
      name: "ElastioInventoryEventTarget",
      description:
        "Role assumed by EventBridge to send events to the Elastio Connector",

      assumeRolePolicy: {
        Action: "sts:AssumeRole",
        Principal: {
          Service: "events.amazonaws.com",
        },
      },
      statements: {
        SendEventsToConnectorAccount: [
          {
            Action: ["events:PutEvents"],
            Resource: [
              `arn:aws:events:*:${inputs.connectorAccountId}:event-bus/elastio-*`,
            ],
          },
        ],
      },
    },

    asset_region_stack_deployer: {
      type: "aws_iam_role",
      name: "ElastioAssetRegionStackDeployer",
      description: "Used by Cloudformation to deploy region-level stack",
      assumeRolePolicy: {
        Action: "sts:AssumeRole",
        Principal: {
          Service: "cloudformation.amazonaws.com",
        },
      },
      statements: {
        ManageElastioEventBridgeRules: [
          {
            Action: [
              "events:DescribeRule",
              "events:ListTargetsByRule",
              "events:ListTagsForResource",
              "events:PutRule",
              "events:PutTargets",
              "events:RemoveTargets",
              "events:DeleteRule",
              "events:EnableRule",
              "events:DisableRule",
            ],
            Resource: [`arn:aws:events:*:{{account_id}}:rule/elastio-*`],
          },
          {
            Action: [
              // Allows assigning of `inventory_event_target` role
              // to the event targets
              "iam:PassRole",
            ],
            Resource: "{{aws_iam_role.inventory_event_target.arn}}",
          },
        ],
      },
    },

    cloud_connector: cloudConnectorRole(inputs),
  };

  // new ssm.StringParameter(this, "assetAccountStackName", {
  //   parameterName: "/elastio/asset/account/stack-name",
  //   description:
  //     "The name of the Asset Account CloudFormation stack used " +
  //     "for discovery by the Cloud Connector",
  //   stringValue: Aws.STACK_NAME,
  // });
}
