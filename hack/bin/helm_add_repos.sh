#!/bin/bash

set -o nounset \
    -o errexit

main() {
    helm_repo_add "$HELM_CHART_NAME" "$HELM_CHART_URL"

    log "Downloading $HELM_CHART_NAME tarball from $HELM_CHART_URL into $HELM_CHART_DIR_TARBALL now."
    helm_pull "$HELM_CHART_VERSION" \
              "$HELM_CHART_NAME" \
              "$HELM_CHART_DIR_TARBALL"

    log "Downloading and untarring $HELM_CHART_NAME from $HELM_CHART_URL into $HELM_CHART_DIR_UNTAR now."
    helm_pull "$HELM_CHART_VERSION" \
              "$HELM_CHART_NAME" \
              "$HELM_CHART_DIR_UNTAR" \
              "true"
}

declare -r helm_repo_lib="hack/lib/helm/helm_repo.sh"
if [ -f "$helm_repo_lib" ]; then
    # shellcheck source=../lib/helm/helm_repo.sh
    source "$helm_repo_lib"
fi

declare -r helm_pull_lib="hack/lib/helm/helm_pull.sh"
if [ -f "$helm_pull_lib" ]; then
    # shellcheck source=../lib/helm/helm_pull.sh
    source "$helm_pull_lib"
fi

declare -r cert_manager_env="hack/env/helm/cert-manager.env"
if [ -f "$cert_manager_env" ]; then
    # shellcheck source=../env/helm/cert-manager.env
    source "$cert_manager_env"
fi

declare -r utils_lib="hack/lib/util.sh"
if [ -f "$utils_lib" ]; then
    # shellcheck source=../lib/util.sh
    source "$utils_lib"
fi

main "$@"
