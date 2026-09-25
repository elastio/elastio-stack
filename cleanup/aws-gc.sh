#!/usr/bin/env bash

set -euo pipefail

script_dir=$(dirname "${BASH_SOURCE[0]}")

python_script="$script_dir/aws-gc.py"

echo Checking Python code with mypy...
mypy "$python_script" --config-file "$script_dir/mypy.ini"

"$python_script" "$@"
