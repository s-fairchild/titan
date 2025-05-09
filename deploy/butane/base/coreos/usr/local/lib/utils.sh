#!/bin/bash

log() {
    msg="$1"

    stack_level="${2:-1}"
    script_name="$(basename "$0") "
    msg_prefix="$script_name - ${FUNCNAME[${stack_level}]}"

    echo "$$ - $msg_prefix: $msg"
}
