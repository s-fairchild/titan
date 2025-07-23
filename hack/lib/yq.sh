# shellcheck disable=SC2148

# yq()
# yq is a portable command-line data file processor (https://github.com/mikefarah/yq/) 
# See https://mikefarah.gitbook.io/yq/ for detailed documentation and examples.
#
# Use "yq [command] --help" for more information about a command.
yq() {
    image="docker.io/mikefarah/yq:latest"

           # -v yq_out:/workdir/out:z \
    podman run \
           --name yq \
           --security-opt label=disable \
           -i \
           --rm \
           --env-host \
           -v "${PWD}":/workdir \
           "$image" \
           "$@"
}

# TODO create a directory named prefix
get_merge_file_prefix() {
    basename "$(dirname "$1")"
}
