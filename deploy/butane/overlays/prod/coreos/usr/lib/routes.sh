#!/bin/bash

set -o nounset

routes_add_table_dev() {
    local -r table="$1"
    local -r net="$2"
    local -r dev="${3:-$net}"
    log "starting"

    log "Adding route $net to table $table via dev $dev"

    if ip route add \
            table "$table" \
            "$net" \
            dev "$dev"; then
        log "Successfully added network route $net to table $table via dev $dev"
    fi
}

routes_add_table_gateway() {
    local -r table="$1"
    local -r net="$2"
    local -r gwy="$3"
    log "starting"
    log "Adding route $net to table $table via ip $gwy"

    if ip route add \
            table "$table" \
            "$net" \
            via "$gwy"; then
        log "Successfully added network route $net to table $table via ip $gwy"
    fi
}

routes_add_host_dev() {
    local -r net="$1"
    local -r dev="$2"
    log "starting"
    log "Adding route $net via dev $dev"

    if ip route add \
            "$net" \
            dev "$dev"; then
        log "Successfully added network route $net via dev $dev"
    fi
}

declare -r utils=/usr/local/lib/utils.sh
if [ -f "$utils" ]; then
    # shellcheck source=../../../../../base/coreos/usr/lib/utils.sh
    source "$utils"
fi
