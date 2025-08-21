# shellcheck shell=bash

# generate_token
# https://github.com/alexellis/k3sup#create-a-multi-master-ha-setup-with-external-sql
# https://docs.k3s.io/cli/token
#
# Generate an initial k3s cluster bootstrapping token to stdout
generate_token() {
    # if ! openssl rand -base64 64; then
        # echo "failed to generate k3s token." && exit 1
    # fi

    local token

    if which openssl 1> /dev/null; then
        token="$(openssl rand -base64 64)" || echo "Failed to generate token with openssl"
    else
        token="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 64)"
    fi

    printf "%s" "$token"
}
