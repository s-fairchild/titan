#!/bin/bash

set -o nounset \
    -o errexit

main() {
    local -r base_dir="$1"
    local -r manifests="$2"
    if [ ! -d "$base_dir" ]; then
        abort "$base_dir not found, aborting"
    elif [ ! -d "$manifests" ]; then
        abort "$manifests not found, aborting"
    fi
    generate_kube_manifests base_dir manifests
}

generate_kube_manifests() {
    local -n base="$1"
    local -n dest="$2"
    log "starting"

    kustomize="$(find "$base" -name kustomization.yaml)"

    # shellcheck disable=SC2068
    for k in ${kustomize[@]}; do
        kustomize_source="$(dirname "$k")"
        manifest_name="${kustomize_source##*/}"
        if is_disabled manifest_name \
                       disabled_pkgs; then
            manifest_name+=".yaml"
            log "Generating $manifest_name from $kustomize_source"
            kubectl kustomize "$kustomize_source" > "$dest/$manifest_name"
        fi
    done
}

is_disabled() {
    local -n pkg="$1"
    local -n disabled="$2"
    if [[ $pkg =~ ${disabled[*]} ]]; then
        return 1
    fi

    return 0
}

declare -r utils="hack/utils.sh"
if [ -f "$utils" ]; then
    # shellcheck source=utils.sh
    source "$utils"
fi

declare -r env_file="hack/env/gen_kube_manifests.env"
if [ -f "$env_file" ]; then
    # shellcheck source=env/gen_kube_manifests.env
    source "$env_file"
fi

main "$@"
