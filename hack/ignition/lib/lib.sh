#!/bin/bash

lib="hack/ignition/lib/ignition.sh"
if [ -f "$lib" ]; then
    # shellcheck source=ignition.sh
    source "$lib"
else
    echo "$lib not found. Exiting."
    exit 1
fi

lib="hack/lib/util.sh"
if [ -f "$lib" ]; then
    # shellcheck source=../../lib/util.sh
    source "$lib"
else
    echo "$lib not found. Are you in the repository root?"
    exit 1
fi
