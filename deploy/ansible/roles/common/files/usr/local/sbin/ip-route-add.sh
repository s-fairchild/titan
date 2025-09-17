#!/bin/bash

set -o nounset \
    -o errexit

main() {
    dest_subnet="$1"
    gateway="$2"
    vrf="${3:-}"
    log "starting"

    table_id=""
    route_table_id_get table_id "$vrf" 

    validate_config "$dest_subnet" \
                    "$gateway" \
                    "$vrf" \
                    "$table_id"
    
    if ! check_ip_route_exists "$dest_subnet" "$table_id"; then
        log "Nothing to do. Exiting."
        return 0
    fi

    if ! ip_routes_add "$dest_subnet" \
                  "$gateway" \
                  "$table_id"; then
        abort "failed to add route."
    fi

    log "Complete."
}

validate_config() {
    local -r dest_subnet_conf="$1"
    local -r gateway_conf="$2"
    local -r vrf_conf="${3:-}"
    local -r table_id_conf="${4:-}"
    log "starting"

    local -r abort_suffix="must be set. Check your environment file."

    [ -z "$dest_subnet_conf" ] && abort "DESTINATION_SUBNET $abort_suffix"
    [ -z "$gateway_conf" ] && abort "GATEWAY $abort_suffix"
    [ -z "$vrf_conf" ] && log_warn "VRF not provided."
    [ -z "$table_id_conf" ] && log_warn "Routing table ID not provided."

    log "Configuration found:"
    log "DESTINATION_SUBNET=${dest_subnet_conf}"
    log "GATEWAY=${gateway_conf}"
    log "VRF=${vrf_conf}"
    log "Route table: ${table_id_conf}"
}

# ip_routes_add()
ip_routes_add() {
    local -r subnet="$1"
    local -r ip_dev_or_gateway="$2"
    local -r table="$3"
    log "starting"

    local ip_dev_or_via
    validate_ip_dev_or_gateway "$ip_dev_or_gateway" ip_dev_or_via
    validate_subnet "$subnet"

    cmd=(
        "ip"
        "route"
        "add"
    )

    if [ -n "$vrf" ]; then
        cmd+=(
            "table"
            "$table"
        )
    fi

    cmd+=(
        "$subnet"
        "$ip_dev_or_via"
        "$ip_dev_or_gateway"
    )

    log "${cmd[*]}"
    # shellcheck disable=SC2068
    ${cmd[@]}
}

# check_ip_route_exists()
#
# Checks the routing table to determine if a route exists
#
# Args:
# $1) Subnet with CIDR notation - string
# $2) table - string, int
#
# Returns:
#   0 if route does not exist
#   1 if route exists
check_ip_route_exists() {
    local -r subnet="$1"
    local -r table="${2:-}"
    log "starting"

    cmd=(
        "ip"
        "route"
        "show"
    )

    if [ -n "${table}" ]; then
        cmd+=(
            "table"
            "$table"
        )
    fi

    # shellcheck disable=SC2068
    if ${cmd[@]} | grep -q ^"$subnet"; then
        log "Route to $subnet exists in table $table."
        return 1
    fi
}

# declare -r ip_route_dev="dev"
declare -r ip_route_dev="dev"
# declare -r ip_route_gateway="via"
declare -r ip_route_gateway="via"

# validate_ip_dev_or_gateway()
validate_ip_dev_or_gateway() {
    local -n dev_or_via="$2"
    log "starting"

    if validate_subnet "$1/32"; then
        dev_or_via="$ip_route_gateway"
    elif validate_netdev "$1"; then
        # shellcheck disable=SC2034
        dev_or_via="$ip_route_dev"
    fi

    return 1
}

# route_table_id_get()
route_table_id_get() {
    local -n t="$1"
    local -r vrf="${2:-}"
    log "starting"

    [ -z "$vrf" ] && return

    # shellcheck disable=SC2034
    if ! t="$(ip vrf show "$vrf" | cut -d ' ' -f 2)"; then
        log "failed to find routing table for provided vrf: ${vrf}"
        return 1
    fi
}

# declare -i shell_utils="/usr/local/lib/utils.sh"
declare -r shell_utils="/usr/local/lib/utils.sh"

if [ -f "$shell_utils" ]; then
    echo "Sourcing $shell_utils"
    # shellcheck source=../../../../../../../../shell-utils/usr/local/lib/utils.sh
    source "$shell_utils"
fi

# declare -r shell_utils_network="/usr/local/lib/utils-network.sh"
declare -r shell_utils_network="/usr/local/lib/utils-network.sh"

if [ -f "$shell_utils_network" ]; then
    echo "Sourcing $shell_utils_network"
    # shellcheck source=../../../../../../../../shell-utils/usr/local/lib/utils-network.sh
    source "$shell_utils_network"
fi

if_debug_set_xtrace

main "$@"
