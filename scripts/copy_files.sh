#!/bin/bash
# Copy k3s files to remote server

set -o nounset

main() {
    host="${1:-all}"
    if [[ $host = "rick" ]]; then
        connection_string="root@rick"
        cp_to_rick
        cp_manifests
    elif [[ $host = "expresso" ]]; then
        cp_to_expresso
    elif [[ $host = "all" ]]; then
        cp_to_all
    else
        echo "Usage: ${0} < rick | expresso | all >"
    fi
}

copy_files() {
    scp "${1}" "${connection_string}:${2:-}"
}

cp_to_all() {
    cp_to_rick
    cp_to_expresso
}

cp_to_rick() {
    copy_files k3s_install.env
    copy_files scripts/server_pre_install.sh
    copy_files node/k3s-server-0.service /usr/lib/systemd/system/
    copy_files node/k3s-agent-0.service /usr/lib/systemd/system/
    copy_files node/k3s-agent-0.yaml /usr/local/etc/k3s/
    copy_files node/k3s-server-0.yaml /usr/local/etc/k3s/

    copy_files node/k3s-serverlb.yaml /usr/local/etc/k3s/
    copy_files node/k3s-serverlb.service /usr/lib/systemd/system/
}

cp_manifests() {
    copy_files manifests/jellyfin.yaml /var/local/etc/k3s/manifests/
    copy_files manifests/pihole.yaml /var/local/etc/k3s/manifests/
}

cp_to_expresso() {
    local connection_string="root@expresso"
    scp node/k3s-agent-1.service /usr/lib/systemd/system/
    cp node/k3s-agent-1.yaml /usr/local/etc/
    unset connection_string
}

main "${@}"
