#!/bin/bash

set -o nounset \
    -o errexit

DEBUG="${DEBUG:-"false"}"

if [ "$DEBUG" == "true" ]; then
    set -x
fi

main() {
    log "starting"
    local deploy_env="$1"
    
    serve "$deploy_env" &

    wait "$!"
}

# serve()
# args:
# 1) $1 - string; deploy environment, used to locate ignition environment file to serve
# refs:
# https://www.linuxjournal.com/article/4490?page=0,0%20xinetd%20turtorial
# https://stackoverflow.com/questions/16640054/minimal-web-server-using-netcat
serve() {
    # nc_handle.sh is executed by nc upon receiving requests within the container
    local -r nc_handle_sh="nc_handle.sh"
    log "starting"

    # shellcheck disable=SC2034
    local -r nc_args=(
        -v
        -p
        80
        -e
        "/${nc_handle_sh}"
        -k
        -l
    )

    nc-ctr "$1" \
            nc_args \
            "$nc_handle_sh"
}

# nc-ctr()
# args:
# 1) serve_env - string; file prefix passed to the container, used by handler
# 2) args - nameref, array; passed to nc
# 3) handler - string; executable filename to mount to container
nc-ctr() {
    local -r serve_env="$1"
    local -n args="$2"
    local -r handler="$3"
    log "starting"

    # Custom image with nc installed
    image="docker.io/steve51516/nc:fedora41"

    podman run \
        --name "${ctr:-"$default_ctr_name"}" \
        --security-opt label=disable \
        -i \
        --rm \
        --env=SERVE_ENV="$serve_env" \
        --env=DEBUG="$DEBUG" \
        -v "${PWD}/deploy/.ignition":/data:O \
        -v "${PWD}/hack/ignition/deploy/${handler}":/nc_handle.sh \
        -w /data \
        -p 8080:80/tcp \
        --network=slirp4netns:allow_host_loopback=true \
        "$image" \
        bash -c "nc ${args[*]}"
}

# kill_nc_ctr()
kill_nc_ctr() {
    local -n c="$1"
    log "starting"

    podman container exists "$c" && podman container kill "$c"
}

trap 'kill_nc_ctr default_ctr_name' 1 2 3 6 15 EXIT

# included to provide definitions for shellcheck
utils="hack/lib/util.sh"
if [ -f "$utils" ]; then
    # shellcheck source=../../lib/util.sh
    source "$utils"
else
    echo "$utils not found. Are you in the repository root?"
    exit 1
fi

declare -r default_ctr_name="ign-server"

main "$@"
