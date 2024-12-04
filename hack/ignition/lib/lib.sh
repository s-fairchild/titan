#!/bin/bash

lib="hack/ignition/lib/ignition.sh"
if [ -f "$lib" ]; then
    # shellcheck source=ignition.sh
    source "$lib"
else
    echo "$lib not found. Exiting."
    exit 1
fi

lib="hack/ignition/lib/butane.sh"
if [ -f "$lib" ]; then
    # shellcheck source=butane.sh
    source "$lib"
else
    echo "$lib not found. Exiting."
    exit 1
fi
