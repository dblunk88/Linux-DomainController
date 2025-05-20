#!/usr/bin/env bash
set -euo pipefail

bash -n ./keycloak_setup.sh
bash ./keycloak_setup.sh --help >/tmp/keycloak_help.txt
grep -q "Usage:" /tmp/keycloak_help.txt
TEST_MODE=1 bash ./keycloak_setup.sh --install >/tmp/keycloak_install.txt
grep -q "Skipping Keycloak installation" /tmp/keycloak_install.txt
TEST_MODE=1 bash ./keycloak_setup.sh --configure-google >/tmp/keycloak_google.txt
grep -q "IdP for Google Workspace" /tmp/keycloak_google.txt

