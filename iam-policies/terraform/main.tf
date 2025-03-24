locals {
  policies = {
    for policy in var.policies :
    policy => jsondecode(file("${path.module}/policies/${policy}.json"))
  }
}

resource "aws_iam_policy" "this" {
  for_each = local.policies

  name        = "${var.name_prefix}${each.key}${var.name_suffix}"
  description = each.value.Description
  policy      = jsonencode(each.value.PolicyDocument)

  tags = merge(var.tags, { "elastio:resource" = true })
}
