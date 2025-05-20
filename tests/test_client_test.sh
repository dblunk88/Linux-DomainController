#!/usr/bin/env bash
set -euo pipefail

# Basic sanity checks for client_test.sh
bash -n ./client_test.sh
TEST_MODE=1 ./client_test.sh --dc-ip 127.0.0.1 --realm TEST.REALM >/tmp/client_test.txt
grep -q "Client test script completed" /tmp/client_test.txt
