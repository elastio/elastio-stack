output "stack" {
  description = <<-DESCR
    The outputs of the aws_cloudformation_stack resource.
  DESCR

  value = aws_cloudformation_stack.this
}
