output "policies" {
  description = "A map of the created Elastio IAM policies keyed by their names"

  value = aws_iam_policy.this
}
