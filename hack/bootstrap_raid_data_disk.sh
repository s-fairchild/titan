#!/bin/bash
# Utilities for bootstrapping my baremetal desktop server environment
# It is meant to be sourced and used interactively or by other shell scripts

mdadm_create_new_raid10_data_disk() {
    if [[ $(whoami) != 0 ]]; then
        abort "must be root user"
    fi

    echo "THIS WILL DESTROY ALL DATA ON DEVICES ${*}!!!"
    if confirm; then
        echo "$USER confirmed new raid creation"
    fi
}

abort() {
    err "$*"
    exit 1
}

# Shamelessly stolen from https://tecadmin.net/bash-script-prompt-to-confirm-yes-no/
function confirm() {
    while true; do
        read -p "Do you want to proceed? (YES/NO/CANCEL) " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            [Cc]* ) exit;;
            * ) echo "Please answer YES, NO, or CANCEL.";;
        esac
    done
}

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

log() {
    echo "[$$] $(date --utc): $*"
}

_mdadm_create() {
   declare -trlxg MDADM_CREATE_DEVICES=value
   (
       mdadm create $MDADM_CREATE_DEVICES;
   ) &
   local -trli MDADM_CREATE_PID=$!

   echo "Waiting on $MDADM_CREATE_PID to complete"
    wait $MDADM_CREATE_PID
}

