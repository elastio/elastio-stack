#!/usr/bin/env bash
#
# This is just a little script that can be downloaded from the internet to
# deploy the clientside stack of Elastio backup solution.
#
# Credits: this script is inspired by `https://sh.rustup.rs ` (rustup installer)

set -eu -o pipefail

# set -x
export PS4='+ [${BASH_SOURCE[0]##*/}:${LINENO}${FUNCNAME[0]:+:${FUNCNAME[0]}}] '

reds_tar_name='reds.tar.gz'
reds_tar_url="https://elastio-aws-lambda-binaries.s3.us-east-2.amazonaws.com/prod/${reds_tar_name}"
# Pinned version of terraform
tf_version=0.14.3

usage() {
    cat <<EOF
reds-deploy
The script to download and deploy the elastio services to the client account.

USAGE:
    reds-deploy [OPTIONS]

OPTIONS:
    --stack-name <NAME>      Identifier that will be interpolated in created AWS resources' names
                             to avoid name conflicts. By convention this is the unique name of
                             the company or person who runs this script
    --aws-region <REGION>    AWS region where to deploy the services [default=\$(aws configure get region)]
    -o, --out-dir <PATH>     When specified this will be used as a path where the artifacts will be
                             written to, and they won't be removed by the script.
                             By default artifacts will be written to the temporary directory
                             and they will be removed at the end by the script.
    -h, --help               Prints help information
EOF
}

main() {
    local out_dir
    local stack_name
    local aws_region

    while (( $# > 0 )); do
        case $1 in
            -h | --help)     usage && exit ;;
            -o | --out-dir)  shift && out_dir="$1" ;;
            --stack-name)    shift && stack_name="$1" ;;
            --aws-region)    shift && aws_region="$1" ;;
            *)               ;;
        esac
        shift
    done

    # Verify the commands we are going to use are present ahead of time
    assert_cmd_exists mktemp
    assert_cmd_exists mkdir
    assert_cmd_exists rm
    assert_cmd_exists tar
    assert_cmd_exists unzip

    # Validate the arguments and set proper defaults
    if [ ! -v stack_name ]; then
        log_error "Missing required argument '--stack-name'"
        usage
        exit 2
    fi

    [ -v aws_region ] || aws_region=$(aws configure get region)

    log_info "Using aws_region: $aws_region"

    # Prepare a sandbox on the filesystem where we can save intermediate files
    local temp_dir
    temp_dir=$(mktemp -d 2>/dev/null)
    ensure mkdir -p "$temp_dir"

    local reds_tar_path="${temp_dir}/${reds_tar_name}"

    local untar_path="$temp_dir"

    if [ -v out_dir ]; then
        untar_path="$out_dir"
        ensure mkdir -p "$out_dir"
    fi

    # Download and untar the artifacts to deploy our Red Stack with terraform
    ensure download "$reds_tar_url" "$reds_tar_path"
    ensure tar -C "$untar_path" -zxf "$reds_tar_path"

    ensure deploy_reds "$temp_dir" "$untar_path" "$stack_name" "$aws_region"

    # Since we are good citizens we cleanup after ourselves, though it is not strictly required
    ignore rm -rf "$temp_dir"

    if [ -v out_dir ]; then
        log_info "Downloaded artifacts were successfully saved at $out_dir"
    else
        log_info "Downloaded artifacts were successfully removed"
    fi

}

deploy_reds() {
    local temp_dir=$1
    local artifacts_dir=$2
    local stack_name=$3
    local aws_region=$4
    local terraform=$(get_terraform $temp_dir)

    log_info "Using terraform command via $terraform"
    log_info 'Initializing the remote backend for terraform state...'

    $artifacts_dir/scripts/init-tf-backend-aws.sh \
        --aws-region "$aws_region" \
        --stack-name "$stack_name" \
        --stack-env "prod" \
        --tf-path "$terraform"

    log_info 'Deploying the target services via terraform...'

    pushd "$artifacts_dir/deployment/aws-reds" > /dev/null

    ensure $terraform init \
        -input=false \
        -backend-config "bucket=elastio-prod-${stack_name}-terraform-state" \
        -backend-config "region=$aws_region" \
        -backend-config "dynamodb_table=elastio-prod-${stack_name}-terraform-locks" \
        -backend-config "encrypt=true"

    ensure $terraform apply \
        -input=false \
        -var "aws_region=$aws_region" \
        -var "stack_name=$stack_name" \
        -var "stack_env=prod"

    popd > /dev/null
}

# FIXME: terraform binary is quite large, it might make sense to cache it
# somehow so that the customers don't need to redownload it when reruning this script
get_terraform() {
    local temp_dir=$1

    # Check if the user already has the proper version of terraform installed
    local tf_version_output
    if tf_version_output=$(terraform --version); then
        if [[ "$tf_version_output" =~ Terraform\ v${tf_version}.* ]]; then
            log_info "Found already installed Terraform v$tf_version."
            echo 'terraform'
            return 0
        fi
    fi

    log_info "Could not find existing terraform of version $tf_version. No worries, will download it..."

    # Try to infer what terraform binary we have to download
    local os
    local arch

    case "$OSTYPE" in
        solaris*)   os='solaris' ;;
        darwin*)    os='darwin' ;;
        linux-gnu*) os='linux' ;;
        freebsd*)   os='freebsd' ;;
        openbsd*)   os='openbsd' ;;
        *)          exit_err "unsupported OS: $OSTYPE" ;;
    esac

    arch=$(uname -m)
    case "$arch" in
        amd64)   arch='amd64' ;;
        x86_64)  arch='amd64' ;;
        aarch64) arch='arm' ;;
        *)       exit_err "unsupported arch: $arch" ;;
    esac

    tf_zip_name="terraform_${tf_version}_${os}_${arch}.zip"
    tf_zip_path="$temp_dir/$tf_zip_name"

    ensure download "https://releases.hashicorp.com/terraform/$tf_version/$tf_zip_name" "$tf_zip_path"
    ensure unzip -o -qq "$tf_zip_path" -d "$temp_dir"

    echo "$temp_dir/terraform"
}

this_script_name=$(basename -- "$0")

# Writes to stderr
log_info() {
    echo "INFO [$this_script_name]: $@" >&2
}
log_error() {
    echo "ERROR [$this_script_name]: $@" >&2
}

exit_err() {
    log_error "aborting due to the following error: $1" >&2
    exit 1
}

assert_cmd_exists() {
    if ! cmd_exists "$1"; then
        exit_err "need '$1' (command not found)"
    fi
}

cmd_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Run a command that should never fail. If the command fails execution
# will immediately terminate with an error showing the failing
# command.
ensure() {
    if ! "$@"; then exit_err "command failed: $*"; fi
}

# This is just for indicating that commands' results are being
# intentionally ignored. Usually, because it's being executed
# as part of error handling.
ignore() {
    "$@"
}

# This wraps curl or wget. Try curl first, if not installed, use wget instead.
download() {
    local url=$1
    local output_path=$2
    local err
    local status

    log_info "Downloading from $url to $output_path"

    if cmd_exists curl; then
        err=$(curl --location --silent --show-error "$url" --output "$output_path" 2>&1)
        status=$?
    elif cmd_exists wget; then
        err=$(wget --quiet "$url" -O "$output_path" 2>&1)
        status=$?
    else
        exit_err 'Neither "curl" nor, "wget" command line tool was found. Please install any of them before running this script'
    fi

    if (( $status != 0 )); then
        exit_err "Downloading failed: $err"
    fi
    return $status
}

main "$@"
