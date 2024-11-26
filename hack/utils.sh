#!/bin/bash
# Utilies to be sourced for use in other scripts

# log()
# A wrapper for echo that includes the function name
# Args
# 1) msg - string
# 2) stack_level - int; optional, defaults to calling function
log() {
    local -r msg="${1:-""}"
    local -r stack_level="${2:-1}"
    echo "${FUNCNAME[${stack_level}]}: ${msg}"
}

# abort()
# A wrapper for log that exits with an error code
# The calling calling function is provided for stack_level
# Args
# 1) msg - string; optional, set to empty string if not provided
abort() {
    local -ri origin_stacklevel=2
    log "${1:-}" "$origin_stacklevel"
    log "Exiting"
    exit 1
}

# prompt_yes_no()
# present a y/n prompt to the user
# If y is provided, the function returns taking no action
# if n is provided, abort() is called
# Loops until y|n is entered
prompt_yes_no() {
    local reply
    local -r y="y"
    local -r n="n"

    while true; do
        read -r -N 1 -p "Do you want to proceed? (y/n) " reply

        reply="${reply,,}"
        case $reply in
            "$y")
                # echo is used directly rather than log here to stop this function name from obscuring the output
                echo -e "\nrecieved $reply"
                return
                ;;
            "$n")
                echo -e "\n$reply recieved..."
                abort "not proceeding"
                ;;
            *)
                echo -e "\nInvalid response: $reply != $y|$n"
        esac
    done
}
