output "cloudformation_stack" {
  description = <<DESCR
    The deployed CloudFormation stack may be used as an input for other stacks
    like the `nat-provision` stack to let it inherit the configurations.
  DESCR

  value = aws_cloudformation_stack.this
}
