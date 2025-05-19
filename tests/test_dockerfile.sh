#!/usr/bin/env bash
set -euo pipefail

# Lint Dockerfile with hadolint if available
if command -v hadolint >/dev/null; then
    hadolint Dockerfile
else
    echo "hadolint not installed" >&2
fi
