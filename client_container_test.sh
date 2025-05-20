#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<USAGE
Usage: $0 --dc-ip IP --realm REALM [--user USER --password PASS] [--image IMAGE]

Launches a Docker container simulating a fresh client system and runs
client_test.sh inside it to verify connectivity to the domain controller.
USAGE
}

DC_IP=""
REALM=""
USER="Administrator"
PASSWORD="Passw0rd!"
IMAGE="ubuntu:24.04"

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
        --image)
            IMAGE=$2
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

CMD=("/opt/client_test.sh" --dc-ip "$DC_IP" --realm "$REALM" --user "$USER" --password "$PASSWORD")

if [[ -n "${TEST_MODE:-}" ]]; then
    echo "[TEST_MODE] Skipping docker container run"
else
    docker run --rm -v "$(pwd)":/opt -w /opt "$IMAGE" bash -c "${CMD[*]}"
fi

echo "Client Docker test completed successfully."
