#!/bin/bash -eu

set -o pipefail

STACK_VER="${ELASTIC_STACK_VERSION:-7.13.4}"
KIBANA_URL="${KIBANA_URL:-http://127.0.0.1:5601}"
KIBANA_AUTH="${KIBANA_AUTH:-}"
FLEET_SERVER_URL="${FLEET_SERVER_URL:-https://127.0.0.1:8220}"

AGENT_URL="https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VER}-linux-x86_64.tar.gz"

function install_jq() {
    if ! command -v jq; then
        sudo yum install -y jq
    fi
}
function download_and_install_agent() {
    ENROLLMENT_TOKEN=$(get_enrollment_token)

    cd "$(mktemp -d)"
    curl --silent -LJ "${AGENT_URL}" | tar xzf -
    cd "$(basename "$(basename "${AGENT_URL}")" .tar.gz)"
    sudo ./elastic-agent install --force --insecure --url="${FLEET_SERVER_URL}" --enrollment-token="${ENROLLMENT_TOKEN}"

    # Cleanup temporary directory
    cd ..
    rm -rf "$(pwd)"
}

# Retrieve API keys
function get_enrollment_token() {
    declare -a AUTH=()
    declare -a HEADERS=(
        "-H" "Content-Type: application/json"
    )

    if [ -n "${KIBANA_AUTH}" ]; then
        AUTH=("-u" "${KIBANA_AUTH}")
    fi

    response=$(curl --silent "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/enrollment-api-keys")
    enrollment_key_id=$(echo -n "${response}" | jq -r '.list[1] | select(.name | startswith("Default")) | .id' )
    enrollment_key=$(curl --silent "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/enrollment-api-keys/${enrollment_key_id}" | jq -r '.item.api_key')

    echo -n "${enrollment_key}"
}

install_jq
download_and_install_agent
