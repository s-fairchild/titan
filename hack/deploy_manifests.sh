#!/bin/bash

main() {
    local -r manifests_dir="$1"

    log "Copying all manifests under $manifests_dir"

    local -r server_manifests_loc="/var/lib/rancher/k3s/server/manifests/compute/"
    local -r server="k3s-server-0"
    local -r server_url="$server:$server_manifests_loc"
    for m in $manifests_dir/*.yaml; do
        log "copying manifest $m to $server_url"
        podman -r cp \
                  "$m" \
                  "$server_url"
    done

    log "Completed copying manifets"
}

declare -r utils="hack/utils.sh"
if [ -f "$utils" ]; then
    # shellcheck source=env/gen_kube_manifests.env
    source "$utils"
fi

main "$@"
