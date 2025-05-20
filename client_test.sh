#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<USAGE
Usage: $0 --dc-ip IP --realm REALM [--user USER --password PASS]

This script installs required packages and attempts to join a domain controller
from a fresh system. It acquires a Kerberos ticket and lists available shares to
verify connectivity.
USAGE
}

DC_IP=""
REALM=""
USER="Administrator"
PASSWORD="Passw0rd!"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dc-ip)
            DC_IP=$2
            shift 2
            ;;
        --realm)
            REALM=$2
            shift 2
            ;;
        --user)
            USER=$2
            shift 2
            ;;
        --password)
            PASSWORD=$2
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$DC_IP" || -z "$REALM" ]]; then
    echo "--dc-ip and --realm are required" >&2
    usage
    exit 1
fi

install_packages() {
    if [[ -n "${TEST_MODE:-}" ]]; then
        echo "[TEST_MODE] Skipping package installation"
        return
    fi
    echo "Installing client packages..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y samba smbclient krb5-user winbind
    unset DEBIAN_FRONTEND
}

configure_kerberos() {
    if [[ -n "${TEST_MODE:-}" ]]; then
        echo "[TEST_MODE] Skipping Kerberos configuration"
        return
    fi
    cat >/etc/krb5.conf <<EOF_KRB
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = true
EOF_KRB
}

obtain_ticket() {
    if [[ -n "${TEST_MODE:-}" ]]; then
        echo "[TEST_MODE] Skipping Kerberos ticket acquisition"
        return
    fi
    echo "$PASSWORD" | kinit "${USER}@${REALM}"
}

test_connection() {
    if [[ -n "${TEST_MODE:-}" ]]; then
        echo "[TEST_MODE] Skipping connection test"
        return
    fi
    smbclient -L "$DC_IP" -k || {
        echo "Failed to list shares on $DC_IP" >&2
        exit 1
    }
}

install_packages
configure_kerberos
obtain_ticket
test_connection

echo "Client test script completed successfully."


