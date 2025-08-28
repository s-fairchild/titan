# shellcheck shell=bash

# cleanup()
# useful to call via trap for cleaning up files/directories
#
# args:
# 1) trash - nameref; array of files/directories to delete
cleanup() {
    local -n trash="$1"
    log "starting"

    # shellcheck disable=SC2068
    for t in ${trash[@]}; do
        if [ -f "$t" ] || [ -d "$t" ]; then
            log "Deleting: $t"
            rm -rf "$t"
        fi
    done
}
