tflint {
    required_version = ">= 0.53.0"
}

config {
    plugin_dir = "~/.tflint.d/plugins"
    call_module_type = "local"
}

plugin "terraform" {
    enabled = true
    preset = "all"
}

plugin "aws" {
    enabled = true
    version = "0.38.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

plugin "azurerm" {
    enabled = true
    version = "0.27.0"
    source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# There is no need to create empty `outputs.tf` or `variables.tf` files.
rule "terraform_standard_module_structure" {
  enabled = false
}
