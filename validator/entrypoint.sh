#!/bin/bash

# verify that all required arguments are present
check_argument() {
    if [ -z "$1" ]; then
        >&2 echo "Internal error: Missing $2 environment variable"
        exit 1
    fi
}

# file containing environment variables outputted by init_indy_node within init-node
env_file="/var/lib/indy/indy.env"

# check the env file. It's absense implies that the node has not been initialized
if [ ! -f "$env_file" ]; then
    >&2 echo "Error: Node has not yet need initialized. Please run init-node first"
    exit 1
fi

# import environment variables from the file generated by init_indy_node
. "$env_file"

# check all needed environment variables. These should always be present because they are a direct output of init_indy_node
check_argument "$NODE_NAME" "NODE_NAME"
check_argument "$NODE_IP" "NODE_IP"
check_argument "$NODE_PORT" "NODE_PORT"
check_argument "$NODE_CLIENT_IP" "NODE_CLIENT_IP"
check_argument "$NODE_CLIENT_PORT" "NODE_CLIENT_PORT"

# start the node
exec /usr/bin/env python3 -O /usr/local/bin/start_indy_node "$NODE_NAME" "$NODE_IP" "$NODE_PORT" "$NODE_CLIENT_IP" "$NODE_CLIENT_PORT"
