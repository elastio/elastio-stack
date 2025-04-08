// The order of keys and values matters! This is the order in which

import { InputType } from "zlib";

// the groups will be displayed in the CloudFormation UI and in the docs.
export const group = {
  configurable: "Configurable parameters",
  internal: "Non-configurable (internal) parameters",
  experimental: "Experimental parameters",
};

type BoolInput = {
  type: "bool";
  default?: null | boolean;
};

type StringInput = {
  type: "string";
  default?: null | string;
  allowedValues?: string[];

  /**
   * The allowedPattern is a regular expression that the input value must
   * match. The regular expression must be very conservative in its syntax.
   * It must be compatible with both the CFN (Java) and Terraform (Go)
   * regular expression engines.
   */
  allowedPattern?: string;
};

type NumberInput = {
  type: "number";
  default?: null | number;
};

type StringSetInput = {
  type: "set(string)";
  default?: null | string[];

  /**
   * Allowed pattern for a single item in the string set.
   *
   * The allowedPattern is a regular expression that the input value must
   * match. The regular expression must be very conservative in its syntax.
   * It must be compatible with both the CFN (Java) and Terraform (Go)
   * regular expression engines.
   */
  allowedPattern?: string;
};

export type Input = (BoolInput | StringInput | NumberInput | StringSetInput) & {
  /**
   * The description is required at the type level to make a developer to
   * pay attention to documenting the input parameter. The description will
   * be visible to the end users, so keep it in mind that they will likely
   * read it.
   */
  description?: string;

  /**
   * Whether the parameter is user configurable. If false, the parameter
   * must not be modified by the end users. A special warning will be inserted
   * into the description of the parameter to prevent the form changing the
   * value of the parameter. The value of the parameter is expected to be set
   * by the Elastio Tenant or the Cloud Connector itself (for asset region stack,
   * for example).
   *
   * Default: false
   */
  group?: keyof typeof group;

  /**
   * Set how the parameter is displayed in the CloudFormation UI.
   */
  displayName: string;
};
