#!/usr/bin/env bash
set -euo pipefail

# Simple sanity test for setup.sh
bash -n ./setup.sh
./setup.sh --help >/tmp/setup_help.txt
grep -q "Usage:" /tmp/setup_help.txt

# Run the script in test mode to ensure code paths execute
TEST_MODE=1 ./setup.sh --provision --realm TEST.REALM >/tmp/setup_out.txt
grep -q "Setup complete." /tmp/setup_out.txt
