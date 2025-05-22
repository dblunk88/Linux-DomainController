#!/usr/bin/env bash
set -euo pipefail

# Simple sanity test for setup.sh
bash -n ./setup.sh
bash ./setup.sh --help >/tmp/setup_help.txt
grep -q "Usage:" /tmp/setup_help.txt

# Run the script in test mode to ensure code paths execute
echo "Running test: Default TEST_MODE provision..."
TEST_MODE=1 bash ./setup.sh --provision --realm TEST.REALM >/tmp/setup_out.txt 2>/tmp/setup_err.txt
grep -q "Setup complete." /tmp/setup_out.txt
grep -q "default values" /tmp/setup_err.txt

echo "Checking chrony default config in TEST_MODE..."
if ! grep -q "allow 127.0.0.1" /etc/chrony/chrony.conf; then
    echo "Error: Default chrony config 'allow 127.0.0.1' not found in TEST_MODE!" >&2
    cat /etc/chrony/chrony.conf >&2
    exit 1
fi

echo "Checking for absence of password prompt in TEST_MODE..."
if grep -q "Please enter a strong password" /tmp/setup_out.txt || grep -q "Please enter a strong password" /tmp/setup_err.txt; then
    echo "Error: Password prompt appeared in TEST_MODE!" >&2
    exit 1
fi
echo "Default TEST_MODE provision test passed."

echo "Running test: Custom CHRONY_ALLOW_SUBNET in TEST_MODE..."
TEST_MODE=1 CHRONY_ALLOW_SUBNET="192.168.0.0/24" bash ./setup.sh --provision --realm TEST.CUSTOM.CHRONY >/tmp/setup_custom_chrony_out.txt 2>/tmp/setup_custom_chrony_err.txt
grep -q "Setup complete." /tmp/setup_custom_chrony_out.txt
grep -q "default values" /tmp/setup_custom_chrony_err.txt # config.env.example is still used for other values

echo "Checking chrony custom config in TEST_MODE..."
if ! grep -q "allow 192.168.0.0/24" /etc/chrony/chrony.conf; then
    echo "Error: Custom chrony config 'allow 192.168.0.0/24' not found!" >&2
    cat /etc/chrony/chrony.conf >&2
    exit 1
fi
echo "Custom CHRONY_ALLOW_SUBNET test passed."
