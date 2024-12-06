#!/bin/bash

set -o nounset \
    -o errexit

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

main() {
    log "starting"
    local deploy_env="$1"
    
    ctr="ign-server"
    serve "$deploy_env" &

    wait "$!"
}

serve() {
    local -r nc_exec_cmd="\"echo -e 'HTTP/1.1 200 OK\r\n' && cat ${1}_main.ign\""

    local -r nc_args=(
        -v
        -p 80
        -c
        "$nc_exec_cmd"
        -k
        -l
    )

    nc-ctr bash -c "nc ${nc_args[*]}"
}

# fedora-nc()
nc-ctr() {
    image="docker.io/steve51516/nc:fedora41"

    podman run \
        --name "${ctr:-nc}" \
        --security-opt label=disable \
        -i \
        --rm \
        -v "${PWD}/deploy/.ignition":/data:O \
        -w /data \
        -p 8080:80/tcp \
        --network=slirp4netns:allow_host_loopback=true \
        "$image" \
        "$@"
}

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
