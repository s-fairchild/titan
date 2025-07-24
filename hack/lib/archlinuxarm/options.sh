#!/bin/bash

# declare -r CONFIG_KEY_BOOT_PARTITION="boot_partition"
declare -r CONFIG_KEY_BOOT_PARTITION="boot_partition"
# declare -r CONFIG_KEY_ROOT_PARTITION="root_partition"
declare -r CONFIG_KEY_ROOT_PARTITION="root_partition"
# declare -r CONFIG_KEY_ENV_FILE="user_env_file"
declare -r CONFIG_KEY_ENV_FILE="user_env_file"
# declare -r CONFIG_KEY_TARBALL="tarball_file_name"
declare -r CONFIG_KEY_TARBALL="tarball_file_name"

collect_user_options() {
    local -n config="$1"
    shift
    log "starting"

    optstring=":f:e:r:b:t:h"
    local OPTIND
    local options
    local user_env_file
    local root_partition
    local boot_partition

    while getopts ${optstring} options; do
        case $options in
            e)
                user_env_file="$OPTARG"
                log "environment file $user_env_file will be sourced."
                ;;
            r)
                root_partition="$OPTARG"
                log "$root_partition will be used for the root filesystem."
                ;;
            b)
                # ${string##*( )}"
                boot_partition="${OPTARG}"
                log "$boot_partition will be used for the boot partition."
                ;;
            f)
                tarball_file_name="${OPTARG}"
                log "$tarball_file_name will be used for writing the root filesystem data."
                # optional
                config["$CONFIG_KEY_TARBALL"]="$tarball_file_name"
                ;;
            h)
                usage
                ;;
            :)
                abort "Option -${OPTARG} requires an argument."
                ;;
            ?)
                abort
                ;;
        esac
    done

    # required
    config["$CONFIG_KEY_BOOT_PARTITION"]="${boot_partition:?"-b CONFIG_KEY_BOOT_PARTITION is required."}"
    config["$CONFIG_KEY_ROOT_PARTITION"]="${root_partition:?"-r CONFIG_KEY_ROOT_PARTITION is required."}"
    config["$CONFIG_KEY_ENV_FILE"]="${user_env_file:?"-e CONFIG_KEY_ENV_FILE is required."}"
}

usage() {
    # TODO populate usage message
    log "usage message"
    exit 0
}
