# shellcheck shell=bash

publish_helm_chart() {
    local -n charts="$1"
    local -r server_instance="${2:-"0"}"
    log "starting"

    local -r static_dir="/var/lib/rancher/k3s/server/static/charts/extra"
    local -r remote_container="k3s-server-$server_instance"
    local -r dest_path="$remote_container:$static_dir"

    # shellcheck disable=SC2068
    for chart in ${charts[@]}; do
        log "Copying Chart: $chart to $dest_path/"
        podman -r cp "$chart" "$dest_path/"
    done
}
