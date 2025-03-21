#!/usr/bin/env bash

set -euo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

REQUIRED_TOOLS=(yq jq git tar cloudsmith)

temp_dir=$(mktemp -d)

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    if [[ "${no_clean-}" == "yes" ]]; then
        echo -e "\nSkipping cleanup"
    else
        rm -rf "${temp_dir}"
    fi
}

check_dependencies() {
    local missing_tools=()

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if (( ${#missing_tools[@]} > 0 )); then
        echo "Error: Missing required tools: ${missing_tools[*]}" >&2
        exit 1
    fi
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Release a Terraform module by packaging, publishing, and tagging.

Options:
    -p, --publish      Publish the module to Cloudsmith repository
    -t, --tag-push     Create and push a Git tag for the release
    -m, --module-path  Path to the module directory (required)
    -n, --no-clean     Skip cleanup of temporary files
    -f, --force        Force re-publish of the module
    -h, --help         Show this help message

Example:
    $(basename "$0") -m modules/my-module -p -t
EOF
}

module_publish=no
tag_push=no
module_path=""
no_clean=no
force=no

while :; do
  case "${1-}" in
    -h|--help)
      show_usage
      exit 0
      ;;
    -p|--publish)
      module_publish=yes
      ;;
    -t|--tag-push)
      tag_push=yes
      ;;
    -m|--module-path)
      module_path="${2-}"
      shift
      ;;
    -n|--no-clean)
      no_clean=yes
      ;;
    -f|--force)
      force=yes
      ;;
    *)
      break
      ;;
  esac
  shift
done

check_dependencies

if [[ -z "$module_path" ]]; then
  echo "Module path is required"
  exit 1
fi

if ! [[ -f "$module_path/.module.toml" ]]; then
  echo "Module file not found: $module_path/.module.toml"
  exit 1
fi

module_name="$(yq .module.name $module_path/.module.toml)"
module_version="$(yq .module.version $module_path/.module.toml)"
module_type="$(yq .module.type $module_path/.module.toml)"

if ! echo "$module_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Invalid version format: $module_version (expected: x.y.z)"
  exit 1
fi

if [[ "$module_type" != "terraform" ]]; then
  echo "Invalid module type: $module_type (expected: terraform)"
  exit 1
fi

echo -e "Checking for existing version: $module_name-$module_version"
if [[ "$force" == "no" ]]; then
  # Github fetches the repository with a shallow clone, so we need to fetch all tags
  git fetch origin --tags --quiet

  # Check if the version tag already exists
  if git tag -l | grep -q $module_name-$module_version; then
    echo "Version tag already exists: $module_name-$module_version"
    echo "Skipping publish"
    exit 0
  fi

  # Check if the version already exists in Cloudsmith
  cs_version=$(cloudsmith list packages elastio/public \
    --query "$module_name version:$module_version" \
    -F json 2>/dev/null | \
    yq -r '.data | length')
  if [[ "$cs_version" != "0" ]]; then
    echo "Published module already exists: $module_name-$module_version"
    echo "Skipping publish"
    exit 0
  fi
else
  echo "Force re-publish enabled"
fi

echo "Packaging $module_name-$module_version"
package_file="$temp_dir/terraform-${module_name}-${module_version}.tar.gz"

tar \
  --exclude='.module.toml' \
  --exclude='.terraform' \
  --exclude='*.tfstate*' \
  --exclude='*_override.tf*' \
  -C $module_path \
  -czvf "$package_file" .

echo -e "\nPackage created: $package_file"

if [[ "$module_publish" == "yes" ]]; then
  echo -e "\nPublishing $module_name-$module_version"
  force_opt=$( [[ "$force" == "yes" ]] && echo "--republish" || echo "" )
  cloudsmith push terraform \
    elastio/public \
    $force_opt "$package_file"
else
  echo -e "\nSkipping publish"
fi

if [[ "$tag_push" == "yes" ]]; then
  echo -e "\nTagging $module_name-$module_version"
  force_opt=$( [[ "$force" == "yes" ]] && echo "--force" || echo "" )
  git tag -a $force_opt "$module_name-$module_version" -m "Release $module_name $module_version"
  git push origin $force_opt "$module_name-$module_version"
else
  echo -e "\nSkipping tag push"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Module: $module_name"
    echo "- Version: $module_version"
    [[ "$module_publish" == "yes" ]] && echo "- Status: Published ✅"
    [[ "$tag_push" == "yes" ]] && echo "- Tag: $module_name-$module_version ✅"
  } >> "$GITHUB_STEP_SUMMARY"
fi
