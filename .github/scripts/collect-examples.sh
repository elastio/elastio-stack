#!/usr/bin/env bash

set -euo pipefail

git ls-files --cached --others --exclude-standard \
    | grep '/examples/' \
    | xargs -I{} dirname {} \
    | sort -u
