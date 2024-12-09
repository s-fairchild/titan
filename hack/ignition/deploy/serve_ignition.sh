#!/bin/bash

set -o nounset \
    -o errexit

DEBUG="${DEBUG:-}"

if [ -n "$DEBUG" ]; then
    set -x
fi

main() {
    log "starting"
    local deploy_env="$1"
    
    ctr="ign-server"
    serve "$deploy_env" &

    wait "$!"
}

# serve()
# TODO launch nc via xinetd
# refs:
# https://www.linuxjournal.com/article/4490?page=0,0%20xinetd%20turtorial
# https://stackoverflow.com/questions/16640054/minimal-web-server-using-netcat
serve() {
    # nc_handle.sh is executed by nc upon receiving requests within the container
    local -r nc_handle_sh="nc_handle.sh"

    local -r nc_args=(
        -v
        -p
        80
        -e
        "/${nc_handle_sh}"
        -k
        -l
    )

    nc-ctr bash -c "nc ${nc_args[*]}"
}

# nc-ctr()
nc-ctr() {
    image="docker.io/steve51516/nc:fedora41"

    podman run \
        --name "${ctr:-nc}" \
        --security-opt label=disable \
        -i \
        --rm \
        --env=SERVE_ENV="$deploy_env" \
        --env=DEBUG="$DEBUG" \
        -v "${PWD}/deploy/.ignition":/data:O \
        -v "${PWD}/hack/ignition/deploy/${nc_handle_sh}":/nc_handle.sh \
        -w /data \
        -p 8080:80/tcp \
        --network=slirp4netns:allow_host_loopback=true \
        "$image" \
        "$@"
}

# kill_ctr()
kill_ctr() {
    local -n c="$1"
    podman container exists "$c" && podman container kill "$c"
}

trap 'kill_ctr ctr' 1 2 3 6 15 EXIT

# included to provide definitions for shellcheck
lib="hack/lib/util.sh"
if [ -f "$lib" ]; then
    # shellcheck source=../lib/util.sh
    source "$lib"
else
    echo "$lib not found. Are you in the repository root?"
    exit 1
fi

main "$@"
