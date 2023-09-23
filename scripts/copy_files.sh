#!/bin/bash
# Copy k3s files to remote server

set -o nounset

remote_user="${REMOTE_USER}"
remote_host="${REMOTE_HOST}"
connection_string="${remote_user}@${remote_host}"

copy_files() {
    scp "${1}" "${connection_string}:${2:-}"
}

copy_files k3s_install.env
copy_files scripts/server_pre_install.sh
copy_files node/k3s-server-0.service /usr/lib/systemd/system/
copy_files node/k3s-agent-0.service /usr/lib/systemd/system/
copy_files node/k3s-server-1.service /usr/lib/systemd/system/
copy_files node/k3s-server-1.yaml /usr/local/etc/k3s/
copy_files node/k3s-agent-0.yaml /usr/local/etc/k3s/
copy_files node/k3s-server-0.yaml /usr/local/etc/k3s/

copy_files node/k3s-serverlb.yaml /usr/local/etc/k3s/
copy_files node/k3s-serverlb.service /usr/lib/systemd/system/
