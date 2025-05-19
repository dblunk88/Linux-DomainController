#!/usr/bin/env bash
set -euo pipefail

# setup.sh - configure a Samba Active Directory Domain Controller on Linux
# This script installs Samba, configures Kerberos, and provisions or joins a domain.

usage() {
    cat <<USAGE
Usage: $0 [--provision|--join DOMAIN] [--gui]

Options:
  --provision           Provision a new domain (interactive)
  --join DOMAIN         Join an existing domain as an additional controller
  --gui                 Install optional GUI management tools (Cockpit with addons)

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
    echo "Installing required packages..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y samba smbclient krb5-user winbind \
        bind9 dnsutils
}

configure_kerberos() {
    echo "Configuring Kerberos..."
    cat >/etc/krb5.conf <<KRB
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = true
KRB
}

provision_domain() {
    echo "Provisioning new domain $REALM..."
    samba-tool domain provision --use-rfc2307 --realm="$REALM" --domain="$DOMAIN" \
        --server-role=dc --dns-backend=SAMBA_INTERNAL
}

join_domain() {
    local domain=$1
    echo "Joining existing domain $domain..."
    samba-tool domain join "$domain" DC --dns-backend=SAMBA_INTERNAL --realm="$REALM"
}

install_gui() {
    echo "Installing Cockpit and samba-ad-dc module..."
    apt-get install -y cockpit cockpit-samba-ad-dc || true
    systemctl enable --now cockpit.socket
}

# main
ACTION=""
GUI="false"
DOMAIN=""
REALM="EXAMPLE.COM"

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

install_packages
configure_kerberos

case $ACTION in
    provision)
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

if [[ $GUI == "true" ]]; then
    install_gui
fi

systemctl restart smbd nmbd winbind || true

echo "Setup complete."
