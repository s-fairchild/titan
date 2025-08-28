# shellcheck shell=bash

# helm_repo_add()
#
# args:
# 1) repo_name - string; Name of the Helm Repository to add
# 2) repo_url - string; Valid Helm Repository URL
helm_repo_add() {
    local repo_name="$1"
    local repo_url="$2"
    log "starting"

    if helm_repo_exists "$repo_name"; then
        log "Helm repo $repo_name already exists."
        return
    fi
    validate_url "$repo_url"

    helm repo \
         add \
         "$repo_name" \
         "$repo_url" \
         --force-update
}

helm_repo_exists() {
    local repo_name="$1"
    log "starting"

    local repo_list
    repo_list="$(helm repo list -o json)"

    if jq -e \
       --arg n "$repo_name" \
       '.[] | select(.name == $n)' \
       <<< "$repo_list"; then
        return 0
    fi

    return 1
}

declare -r validate_lib="hack/validate.sh"
if [ -f "$validate_lib" ]; then
    # shellcheck source=../validate.sh
    source "$validate_lib"
fi
