#!/bin/bash

set -o nounset \
    -o errexit

main() {
    for network in "$@"; do
        ensure_routes_host "$network"
    done
}

ensure_routes_host() {
    log "starting"

    local -r prefix="Ensuring host route to network"
    case "$1" in
        "$AGENT_NETWORK_NAME")
            log "$prefix $AGENT_NETWORK_NAME subnet $AGENT_CIDR"
            routes_add_host_dev "$AGENT_CIDR" \
                            "$AGENT_NETWORK_NAME"
            ;;
        "$SERVER_NETWORK_NAME")
            log "$prefix $SERVER_NETWORK_NAME subnet $SERVER_CIDR"
            routes_add_host_dev "$SERVER_CIDR" \
                            "$SERVER_NETWORK_NAME"
            ;;
        "$SERVICE_NETWORK_NAME")
            log "$prefix $SERVICE_NETWORK_NAME subnet $SERVICE_CIDR"
            routes_add_host_dev "$SERVICE_CIDR" \
                            "$SERVICE_NETWORK_NAME"
            ;;
        *)
            log "failed to match provided network $1"
            ;;
    esac
}

declare -r utils_lib=/usr/local/lib/utils.sh
if [ -f "$utils_lib" ]; then
    # shellcheck source=../../../../../base/coreos/usr/lib/utils.sh
    source "$utils_lib"
fi

declare -r routes_lib=/usr/local/lib/routes.sh
if [ -f "$routes_lib" ]; then
    # shellcheck source=../lib/routes.sh
    source "$routes_lib"
fi

if [ -f "$1" ]; then
    # shellcheck source=../../etc/sysconfig/k3s-networks
    source "$1"
fi

shift

main "$@"
