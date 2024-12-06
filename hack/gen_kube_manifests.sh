#!/bin/bash

set -o nounset \
    -o errexit

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

main() {
    local -r base_dir="$1"
    local -r manifests="$2"
    local -r overlay="$3"
    if [ ! -d "$base_dir" ]; then
        abort "$base_dir not found, aborting"
    elif [ ! -d "$manifests" ]; then
        abort "$manifests not found, aborting"
    fi

    generate_kube_manifests "$base_dir" \
                            "$manifests" \
                            "$overlay"
}

generate_kube_manifests() {
    local -r base="$1"
    local -r dest="$2"
    local -r overlay="$3"
    log "starting"

    mapfile kustomize <<< "$(find "$base" -type d -name "$overlay")"

    # shellcheck disable=SC2068
    for k in ${kustomize[@]}; do
        app_name="$(get_app_name "$k")"
        app_manifest="$app_name.yaml"
        if is_disabled "$app_name" \
                       "$disabled_pkgs"; then
            log "Generating $app_manifest from $k"
            kubectl kustomize "$k" > "$dest/$app_manifest"
        fi
    done
}

get_app_name() {
    app="$(dirname "$1")"
    app="$(dirname "$app")"
    app="$(basename "$app")"

    echo "$app"
}

is_disabled() {
    local -r app="$1"
    local -r disabled="$2"
    if [[ $app =~ ${disabled[*]} ]]; then
        return 1
    fi

    return 0
}

declare -r utils="hack/lib/util.sh"
if [ -f "$utils" ]; then
    # shellcheck source=lib/util.sh
    source "$utils"
fi

declare -r env_file="hack/env/gen_kube_manifests.env"
if [ -f "$env_file" ]; then
    # shellcheck source=env/gen_kube_manifests.env
    source "$env_file"
fi

main "$@"
