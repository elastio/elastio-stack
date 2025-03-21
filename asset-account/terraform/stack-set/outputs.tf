
output "stack_set" {
  value       = aws_cloudformation_stack_set.this
  description = <<DESCR
    The outputs of the aws_cloudformation_stack_set resource.
  DESCR
}

output "stack_instances" {
  value       = aws_cloudformation_stack_instances.this
  description = <<DESCR
    The outputs of the aws_cloudformation_stack_instances resource.
  DESCR
}
