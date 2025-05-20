#!/usr/bin/env bash
set -euo pipefail

# Simple Keycloak setup helper

usage() {
    cat <<USAGE
Usage: $0 [--install] [--configure-google]

Options:
  --install           Install Keycloak from keycloak-26.2.4.zip
  --configure-google  Output instructions to configure Keycloak as IdP for Google
USAGE
}

if [[ ${1:-} == "--help" || $# -eq 0 ]]; then
    usage
    exit 0
fi

TEST_MODE=${TEST_MODE:-}
INSTALL=false
CONFIG_GOOGLE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --install)
            INSTALL=true
            ;;
        --configure-google)
            CONFIG_GOOGLE=true
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
done

install_keycloak() {
    echo "Installing Keycloak..."
    if [[ -n "$TEST_MODE" ]]; then
        echo "[TEST_MODE] Skipping Keycloak installation"
        return
    fi
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y openjdk-17-jre-headless unzip
    unset DEBIAN_FRONTEND

    if [[ ! -f keycloak-26.2.4.zip ]]; then
        echo "keycloak-26.2.4.zip not found" >&2
        exit 1
    fi

    unzip -q keycloak-26.2.4.zip -d /opt
    ln -sfn /opt/keycloak-26.2.4 /opt/keycloak
    /opt/keycloak/bin/kc.sh build
}

configure_google() {
    cat <<INFO
To configure Keycloak as the IdP for Google Workspace:
1. Log in to the Keycloak admin console.
2. Create a new SAML client with:
   Client ID: google
   NameID Format: email
   Client Signature Required: OFF
   Valid Redirect URIs: https://www.google.com/a/<YOUR_DOMAIN>/acs
3. Download the IdP metadata from:
   https://<keycloak-host>/realms/master/protocol/saml/descriptor
4. In the Google Admin console, set up a custom SAML app using the downloaded metadata.
INFO
}

if $INSTALL; then
    install_keycloak
fi

if $CONFIG_GOOGLE; then
    configure_google
fi

if ! $INSTALL && ! $CONFIG_GOOGLE; then
    usage
    exit 1
fi

echo "Keycloak script complete."

