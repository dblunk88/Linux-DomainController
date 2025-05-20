#!/usr/bin/env bash
set -euo pipefail

# Basic sanity checks for client_container_test.sh
bash -n ./client_container_test.sh
TEST_MODE=1 ./client_container_test.sh --dc-ip 127.0.0.1 --realm TEST.REALM >/tmp/client_container.log
grep -q "Client Docker test completed" /tmp/client_container.log
