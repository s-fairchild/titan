# shellcheck shell=bash

helm_pull() {
    local version="$1"
    local repo_name="$2"
    local chart_out="${3:-"./"}"
    local untar="${4:-"false"}"
    log "starting"

    local -a args=(
        "$repo_name"
        "--version"
        "$version"
    )

    if [ "$untar" == "false" ]; then
        log "untarring enabled."
        args=(
         "--untardir"
         "--untardirdir"
        )
        log "Added args: ${args[*]}"
    else
        args=(
            "--destination"
        )
    fi
    args+=("$chart_out")

    # shellcheck disable=SC2068
    helm pull ${args[@]}
}
