#!/usr/bin/env bash

set -euo pipefail

tf_modules=()
while IFS= read -r -d '' module_cfg; do
    case $(yq -o y .module.type "$module_cfg") in
    null)
        echo "Warning: module type not found in $module_cfg" >&2
        exit 1
        ;;
    terraform)
        echo "Found Terraform module in $module_cfg" >&2
        tf_modules+=("$(dirname "$module_cfg")")
        ;;
    esac
done < <(find . -name .module.toml -print0)

printf '%s\n' "${tf_modules[@]}"
