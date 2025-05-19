#!/usr/bin/env bash
set -euo pipefail

# Simple sanity test for setup.sh
bash -n ./setup.sh
./setup.sh --help >/tmp/setup_help.txt
grep -q "Usage:" /tmp/setup_help.txt
