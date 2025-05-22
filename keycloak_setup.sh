#!/usr/bin/env bash
set -euo pipefail

KEYCLOAK_VERSION="24.0.5"
KEYCLOAK_DOWNLOAD_URL="https://github.com/keycloak/keycloak/releases/download/$KEYCLOAK_VERSION/keycloak-$KEYCLOAK_VERSION.zip"

# Simple Keycloak setup helper

usage() {
    cat <<USAGE
Usage: $0 [--install] [--configure-google] [--start-dev-instance]

Options:
  --install             Install Keycloak from keycloak-$KEYCLOAK_VERSION.zip
  --configure-google    Output instructions to configure Keycloak as IdP for Google
  --start-dev-instance  Start a Keycloak development instance after installation (if --install is also used or Keycloak is present).
USAGE
}

if [[ ${1:-} == "--help" || $# -eq 0 ]]; then
    usage
    exit 0
fi

TEST_MODE=${TEST_MODE:-}
INSTALL=false
CONFIG_GOOGLE=false
START_DEV=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --install)
            INSTALL=true
            ;;
        --configure-google)
            CONFIG_GOOGLE=true
            ;;
        --start-dev-instance)
            START_DEV=true
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
    apt-get install -y openjdk-17-jre-headless unzip curl
    unset DEBIAN_FRONTEND

    if [[ ! -f "keycloak-$KEYCLOAK_VERSION.zip" ]]; then
        echo "keycloak-$KEYCLOAK_VERSION.zip not found. Attempting to download..."
        if ! curl -fsSL -o "keycloak-$KEYCLOAK_VERSION.zip" "$KEYCLOAK_DOWNLOAD_URL"; then
            echo "Error: Failed to download keycloak-$KEYCLOAK_VERSION.zip from $KEYCLOAK_DOWNLOAD_URL" >&2
            # Clean up partially downloaded file if any
            rm -f "keycloak-$KEYCLOAK_VERSION.zip"
            exit 1
        fi
        echo "Download successful."
    fi

    if [[ ! -f "keycloak-$KEYCLOAK_VERSION.zip" ]]; then
        echo "Error: keycloak-$KEYCLOAK_VERSION.zip not found even after download attempt." >&2
        exit 1
    fi

    # Ensure a clean extraction by removing previous installation if it exists
    echo "Removing previous Keycloak installation directory if it exists..."
    sudo rm -rf "/opt/keycloak-$KEYCLOAK_VERSION"
    sudo rm -f "/opt/keycloak" # Remove symlink if it exists

    echo "Unzipping Keycloak..."
    if ! unzip -q "keycloak-$KEYCLOAK_VERSION.zip" -d /opt; then
        echo "Error: Failed to unzip Keycloak archive." >&2
        exit 1
    fi

    echo "Creating symlink..."
    if ! ln -sfn "/opt/keycloak-$KEYCLOAK_VERSION" /opt/keycloak; then
        echo "Error: Failed to create symlink for Keycloak." >&2
        exit 1
    fi
    
    echo "Building Keycloak..."
    if ! /opt/keycloak/bin/kc.sh build; then
        echo "Error: Keycloak build failed." >&2
        exit 1
    fi
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

start_dev_instance() {
    if [[ ! -f "/opt/keycloak/bin/kc.sh" ]]; then
        echo "Error: Keycloak does not seem to be installed at /opt/keycloak. Please run with --install first or ensure it's installed." >&2
        exit 1
    fi

    echo "Attempting to start Keycloak in development mode..."
    # Run in background, redirecting stdout and stderr to a log file.
    # Using sudo in case kc.sh needs to write to /opt/keycloak or subdirs owned by root,
    # or if it attempts to bind to privileged ports (though start-dev usually uses 8080).
    if sudo nohup /opt/keycloak/bin/kc.sh start-dev > /tmp/keycloak_start_dev.log 2>&1 & then
        echo "Keycloak started in background. It might take a minute to be fully available."
        echo "Check logs: /tmp/keycloak_start_dev.log"
        echo "Default URL: http://localhost:8080"
        echo "Default admin user (if first time): Set via KEYCLOAK_ADMIN and KEYCLOAK_ADMIN_PASSWORD environment variables before first start, or check logs for generated password / setup instructions."
    else
        echo "Error: Failed to launch Keycloak in background." >&2
        echo "Check /tmp/keycloak_start_dev.log for details if the file was created."
        exit 1
    fi
}

if $START_DEV; then
    if ! $INSTALL && [[ ! -d "/opt/keycloak" ]]; then
      echo "Warning: --start-dev-instance was passed without --install, and Keycloak is not detected at /opt/keycloak. Attempting to start anyway, but it may fail if not installed." >&2
    fi
    start_dev_instance
fi


if ! $INSTALL && ! $CONFIG_GOOGLE && ! $START_DEV; then
    usage
    exit 1
fi

echo "Keycloak script complete."

