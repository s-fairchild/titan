#!/bin/bash

# declare -r CONFIG_KEY_BOOT_PARTITION="boot_partition"
declare -r CONFIG_KEY_BOOT_PARTITION="boot_partition"
# declare -r CONFIG_KEY_ROOT_PARTITION="root_partition"
declare -r CONFIG_KEY_ROOT_PARTITION="root_partition"
# declare -r CONFIG_KEY_ENV_FILE="user_env_file"
declare -r CONFIG_KEY_ENV_FILE="user_env_file"
# declare -r CONFIG_KEY_TARBALL="tarball_file_name"
declare -r CONFIG_KEY_TARBALL="tarball_file_name"
# declare -r CONFIG_KEY_RPI_MODEL="rpi_model"
declare -r CONFIG_KEY_RPI_MODEL="rpi_model"
# declare -r CONFIG_KEY_SSH_PUBLIC_KEY="ssh_public_key"
declare -r CONFIG_KEY_SSH_PUBLIC_KEY="ssh_public_key"


collect_user_options() {
    local -n config="$1"
    shift
    log "starting"

    optstring=":k:m:f:e:r:b:t:hl"
    local OPTIND
    # local options

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
                ;;
            m)
                rpi_model="${OPTARG}"
                board_support_check "$rpi_model"
                log "$rpi_model Board type selected"
                ;;
            l)
                board_support_list
                exit 0
                ;;
            k)
                key="$OPTARG"
                is_ssh_key_public "$key"
                log "$key ssh public key will be copied to /root/.ssh/authorized_keys and /home/alarm/.ssh/authorized_keys"
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
    config["$CONFIG_KEY_RPI_MODEL"]="${rpi_model:?"-m CONFIG_KEY_RPI_MODEL required."}"
    config["$CONFIG_KEY_SSH_PUBLIC_KEY"]="${key:?"-k CONFIG_KEY_SSH_PUBLIC_KEY is required."}"
    # shellcheck disable=SC2034
    # optional
    config["$CONFIG_KEY_TARBALL"]="${tarball_file_name:-$BOOL_FALSE}"
}

board_support_list() {
    echo "Supported boards: $SUPPORTED_BOARDS"
}

usage() {
    # TODO populate usage message
    log "usage message"
    exit 0
}
