#!/usr/bin/env bash
set -euo pipefail

# main
ACTION=""
GUI="false"
DOMAIN=""
REALM="EXAMPLE.COM"
ADMIN_PASS="${ADMIN_PASS:-Passw0rd!}"

# Optional configuration file
CONFIG_FILE="./config.env"
EXAMPLE_CONFIG_FILE="./config.env.example"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "Sourcing configuration from $CONFIG_FILE" >&2
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
elif [[ -f "$EXAMPLE_CONFIG_FILE" ]]; then
    echo "Config file $CONFIG_FILE not found. Creating from example." >&2
    cp "$EXAMPLE_CONFIG_FILE" "$CONFIG_FILE"
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

# Warn if the configuration file still contains the defaults
if [[ -f "$CONFIG_FILE" && -f "$EXAMPLE_CONFIG_FILE" ]]; then
    if cmp -s "$CONFIG_FILE" "$EXAMPLE_CONFIG_FILE"; then
        echo "WARNING: $CONFIG_FILE contains default values. Edit this file before running in production." >&2
    fi
fi

# Enable reduced functionality when running in CI tests
TEST_MODE=${TEST_MODE:-}

# setup.sh - configure a Samba Active Directory Domain Controller on Linux
# This script installs the `samba-ad-dc` service, configures Kerberos and Samba,
# and provisions or joins a domain.

usage() {
    cat <<USAGE
Usage: $0 [--provision|--join DOMAIN] [--gui]

Options:
  --provision           Provision a new domain (interactive)
  --join DOMAIN         Join an existing domain as an additional controller
  --gui                 Install optional GUI management tools (Cockpit with 'samba-ad-dc' module)

Run as root on a clean Linux server. The script is tested on Debian/Ubuntu.
USAGE
}

if [[ ${1:-} == "--help" || $# -eq 0 ]]; then
    usage
    exit 0
fi

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root" >&2
    exit 1
fi

install_packages() {
    if [[ -n "$TEST_MODE" ]]; then
        echo "[TEST_MODE] Skipping package installation"
        return
    fi
    echo "Installing required packages..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y samba-ad-dc samba smbclient krb5-user winbind \
        bind9 dnsutils chrony python3-ldb python3-samba
    unset DEBIAN_FRONTEND
}

cleanup_samba_conf() {
    if [[ -n "$TEST_MODE" ]]; then
        echo "[TEST_MODE] Skipping Samba config cleanup"
        return
    fi
    if [[ -f /etc/samba/smb.conf ]]; then
        echo "Backing up existing /etc/samba/smb.conf"
        mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
    fi
}

configure_kerberos() {
    if [[ -n "$TEST_MODE" ]]; then
        echo "[TEST_MODE] Skipping Kerberos configuration"
        return
    fi
    echo "Configuring Kerberos..."
    cat >/etc/krb5.conf <<KRB
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = true
KRB
}

provision_domain() {
    if [[ -n "$TEST_MODE" ]]; then
        echo "[TEST_MODE] Skipping domain provisioning"
        return
    fi
    echo "Provisioning new domain $REALM..."
    samba-tool domain provision --use-rfc2307 --realm="$REALM" --domain="$DOMAIN" \
        --server-role=dc --dns-backend=SAMBA_INTERNAL --adminpass="$ADMIN_PASS"
}

join_domain() {
    local domain=$1
    if [[ -n "$TEST_MODE" ]]; then
        echo "[TEST_MODE] Skipping join domain $domain"
        return
    fi
    echo "Joining existing domain $domain..."
    samba-tool domain join "$domain" DC --dns-backend=SAMBA_INTERNAL --realm="$REALM" \
        --adminpass="$ADMIN_PASS"
}

configure_samba() {
    if [[ -n "$TEST_MODE" ]]; then
        echo "[TEST_MODE] Skipping Samba configuration"
        return
    fi
    echo "Configuring Samba..."
    cat >/etc/samba/smb.conf <<CONF
[global]
    workgroup = ${DOMAIN:-$(echo "$REALM" | cut -d. -f1)}
    realm = $REALM
    server role = active directory domain controller
    idmap_ldb:use rfc2307 = yes

[sysvol]
    path = /var/lib/samba/sysvol
    read only = no

[netlogon]
    path = /var/lib/samba/sysvol/${REALM,,}/scripts
    read only = no
CONF
}

install_gui() {
    if [[ -n "$TEST_MODE" ]]; then
        echo "[TEST_MODE] Skipping GUI installation"
        return
    fi
    echo "Installing Cockpit and attempting to install samba-ad-dc module..."
    export DEBIAN_FRONTEND=noninteractive
    # Install cockpit first
    if ! apt-get install -y cockpit; then
        echo "Error: Failed to install Cockpit." >&2
        exit 1 # Cockpit itself is a hard requirement for --gui
    fi

    # Attempt to install the samba-ad-dc module, but make it optional
    if ! apt-get install -y cockpit-samba-ad-dc; then
        echo "Warning: The 'cockpit-samba-ad-dc' package could not be found for this Ubuntu version. Skipping this specific GUI module." >&2
        # Do not exit, allow script to continue
    fi
    unset DEBIAN_FRONTEND
    systemctl enable --now cockpit.socket
}

configure_ntp() {
    if [[ -n "$TEST_MODE" ]]; then
        echo "[TEST_MODE] Skipping NTP configuration"
        return
    fi
    echo "Configuring time synchronization..."

    # Default CHRONY_ALLOW_SUBNET if not set or empty
    CHRONY_ALLOW_SUBNET="${CHRONY_ALLOW_SUBNET:-127.0.0.1}"

    cat >/etc/chrony/chrony.conf <<NTP
pool pool.ntp.org iburst
allow ${CHRONY_ALLOW_SUBNET}
NTP
    if ! systemctl enable --now chrony; then
        echo "Error: Failed to enable or start chrony service." >&2
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --provision)
            ACTION="provision"
            shift
            ;;
        --join)
            ACTION="join"
            DOMAIN=$2
            shift 2
            ;;
        --gui)
            GUI="true"
            shift
            ;;
        --realm)
            REALM=$2
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Derive DOMAIN from REALM if not explicitly set
if [[ -z "$DOMAIN" ]]; then
    DOMAIN=$(echo "$REALM" | cut -d. -f1)
    echo "DOMAIN not set; defaulting to $DOMAIN" >&2
fi

install_packages
configure_kerberos
configure_ntp
cleanup_samba_conf

case $ACTION in
    provision)
        if [[ -z "$TEST_MODE" && ("$ADMIN_PASS" == "Passw0rd!" || -z "$ADMIN_PASS") ]]; then
            echo "Default or empty administrator password detected."
            new_pass=""
            confirm_pass=""
            for i in {1..3}; do
                read -s -r -p "Please enter a strong password for the domain administrator: " new_pass
                echo >&2 # Newline after password input
                read -s -r -p "Confirm password: " confirm_pass
                echo >&2 # Newline after password input
                if [[ "$new_pass" == "$confirm_pass" ]]; then
                    if [[ -z "$new_pass" ]]; then
                        echo "Password cannot be empty. Please try again." >&2
                    else
                        ADMIN_PASS="$new_pass"
                        echo "Password updated." >&2
                        break
                    fi
                else
                    echo "Passwords do not match. Please try again." >&2
                fi
                if [[ $i -eq 3 ]]; then
                    echo "Failed to set password after 3 attempts. Exiting." >&2
                    exit 1
                fi
            done
        fi
        provision_domain
        ;;
    join)
        if [[ -z $DOMAIN ]]; then
            echo "--join requires a DOMAIN" >&2
            exit 1
        fi
        join_domain "$DOMAIN"
        ;;
    *)
        echo "No action specified" >&2
        usage
        exit 1
        ;;
esac

configure_samba

if [[ $GUI == "true" ]]; then
    install_gui
fi

if [[ -z "$TEST_MODE" ]]; then
    if ! systemctl enable --now samba-ad-dc; then
        echo "Error: Failed to enable or start samba-ad-dc service." >&2
        exit 1
    fi
else
    echo "[TEST_MODE] Skipping service start"
fi

echo "Setup complete."
