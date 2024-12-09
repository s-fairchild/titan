#!/bin/bash

set -o nounset \
    -o errexit

if [ -n "$DEBUG" ]; then
    set -x
fi

main() {
    handle "$@"
}

handle() {
    # TODO add file exists check, send 404 if not found
    echo -e 'HTTP/1.1 200 OK\r\n' && cat "/data/${SERVE_ENV}_main.ign"
}

main "$@"
