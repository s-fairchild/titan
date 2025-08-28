# shellcheck disable=SC2148
# Utilies to be sourced for use in other scripts

# log()
# log is a wrapper for echo that includes the function name
# Args
# 1) msg - string
# 2) stack_level - int; optional, defaults to calling function
log() {
    local -r msg="${1}"
    local -ri stack_level="${2:-1}"

    local -r calling_func="${FUNCNAME[${stack_level}]}"
    echo -e "$calling_func: ${msg}"
}

# abort()
# abort is a wrapper for log that exits with an error code
# 1) msg - string; optional, additional messages to log before exiting
abort() {
    local -ri origin_stacklevel=2

    if [ -n "$1" ]; then
        log "${1}" "$origin_stacklevel"
    fi

    log "Exiting"
    exit 1
}

# check_dir_exists()
check_dir_exists() {
    [ -d "$1" ] || return 1
}

check_file_exists() {
    [ -f "$1" ] || return 1
}
