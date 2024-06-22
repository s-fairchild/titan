#!/bin/bash

main() {
    local -r manifests="deploy/manifests"
    local -r base_dir="pkg/"
    generate_kube_manifests base_dir manifests
}

generate_kube_manifests() {
    local -n base="$1"
    local -n dest="$2"
    kustomize="$(find "$base" -name kustomization.yaml)"


    # shellcheck disable=SC2068
    for k in ${kustomize[@]}; do
        kustomize_source="$(dirname "$k")"
        manifest_name="${kustomize_source##*/}.yaml"
        echo "Generating $manifest_name from $kustomize_source"
        kubectl kustomize "$kustomize_source" > "$dest/$manifest_name"
    done
}

main "$@"
