terraform {
  required_version = "~> 1.9"

  required_providers {
    # It's used by child modules
    # tflint-ignore: terraform_unused_required_providers
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # It's used by child modules
    # tflint-ignore: terraform_unused_required_providers
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}
