#!/bin/bash

# prints the usage of this script
usage() {
    echo "
Usage:
    setup-sovrin.sh [ARG..]

Options:
    -c, --config file-path      Configuration file for noninteractive usage
    -e, --engine engine         Container engine to use: docker or podman
    -h, --help                  Print this help message
    -v, --verbose               Print verbose output"
}

# checks that a given argument is set and prints an error if not
check_argument() {
    if [ -z "$1" ]; then
        >&2 echo "Error: $2"
        exit 22
    fi
}

# checks the existence of a command
has_command() {
    hash "$1" 2>/dev/null || return 1
    return 0
}

# prompts the user to input data
# allows setting a default value and help text
get_user_input() {
    local varname="$1"
    local msg="$2"
    local help="$3"
    local default="$4"

    while true; do
        local prompt="$msg$(if [ "${#default}" -gt 0 ]; then echo " (default: $default)"; fi): "
        read -p $'\e[1;33m?\e[0m '"$prompt"

        if [ "${#REPLY}" -eq 0 ] && [ "${#default}" -gt 0 ]; then
            printf -v "$varname" '%s' "$default"
            return 0
        else
            if [ "${#REPLY}" -eq 0 ] || [ "$REPLY" = "?" ]; then
                echo "Help: $help"
                continue
            fi
        fi
        printf -v "$varname" '%s' "$REPLY"
        return 0
    done
}

# presents the user with a yes or no choice
get_user_confirmation() {
    local msg="$1"
    local help="$2"
    local default=$3

    local prompt=$'\e[1;34m?\e[0m '"$msg ($(if [ $default -eq 0 ]; then echo "Y/n"; else echo "N/y"; fi)/?): "

    while true; do
        read -p "$prompt" yn
        case $yn in
            [Yy]* ) return 0; ;;
            [Nn]* ) return 1; ;;
            ? ) echo "Help: $help"; continue;;
            * ) return $default; ;;
        esac
    done
}

wallet_volume_name="sovrin-wallet"
ledger_volume_name="sovrin-ledger"

# parse the command options using getopt
opts=$(getopt -o 'hve:c:' --longoptions 'help,verbose,engine:,config:' -n 'sovrin-setup' -- "$@")

# exit if getopt throws an error
if [ $? -ne 0 ]; then
    exit 1
fi

# apply the rearranged arguments
eval set -- "$opts"

# iterate over and parse the given flags
while true; do
    case "$1" in
        '-c'|'--config')
            config=$2
            shift 2
            continue
            ;;
        '-e'|'--engine')
            engine=$(echo "$2" | tr '[:upper:]' '[:lower:]')
            shift 2
            continue
            ;;
        '-h'|'--help')
            usage
            exit 0
            ;;
        '-v'|'--verbose')
            verbose="--verbose"
            shift
            continue
            ;;
        '--')
            shift
            break
            ;;
        *)
            >&2 echo "Error: unexpected internal error"
            exit 1
            ;;
    esac
done

# use interactive mode if no config file has been given
if [ -z "${config+x}" ]; then
    echo -e "\033[1mWelcome to the Sovrin setup\033[0m
This script will bootstrap your start into Sovrin by setting up a wallet and validator node.
All you have to do is enter the necessary informations.
Typing \033[1m?\033[0m will print an explaination what exactly is being asked for.\n"

    while true; do
        get_user_input \
            "node_name" \
            "Node name" \
            "The name your node will be known as publicly"
        get_user_input \
            "pool_name" \
            "Pool name" \
            "The name the pool (network) configuration will be saved as locally" \
            "buildernet"
        get_user_input \
            "wallet_name" \
            "Wallet name" \
            "The name your wallet will be saved as locally" \
            "buildernet_wallet"

        get_user_confirmation \
            "Recover steward keys?" \
            "This option allows the usage of a previous steward seed to recover your keypair. Otherwise a new seed and keypair is being generated" \
            1
        if [ $? -eq 0 ]; then
            get_user_input "steward_seed" "Steward seed" "Your previously used steward seed"
        fi

        get_user_confirmation \
            "Recover node keys?" \
            "This option allows the usage of a previous node seed to recover your keypair. Otherwise a new seed and keypair is being generated" \
            1
        if [ $? -eq 0 ]; then
            get_user_input "node_seed" "Node seed" "Your previously used node seed"
        fi

        get_user_confirmation \
            "Are all data correct?" \
            "Please verify that all informations you entered are correct" \
            0
        if [ $? -eq 0 ]; then
            break
        fi
    done
else
    if [ -f "$config" ]; then
        # import setup config from a file
        . "$config"
    else
        >&2 echo "Error: cannot read config file at $config"
        exit 22
    fi
fi

# verify that all required config entries are set
check_argument "$node_name" "Missing node name in config"
check_argument "$pool_name" "Missing pool name in config"
check_argument "$wallet_name" "Missing wallet name in config"

# check which container engine to use
if [ -z "${engine+x}" ]; then
    has_command "podman"
    if [ $? -eq 0 ]; then
        engine="podman"
    else
        has_command "docker"
        if [ $? -eq 0 ]; then
            engine="docker"
        else
            >&2 echo "Error: Cannot find docker or podman executable"
            exit 1
        fi
    fi
fi

# build the container images
echo "Building indy-cli image..."
$engine build -t indy-cli ./indy-cli > /dev/null
echo "Building validator image..."
$engine build -t validator ./validator > /dev/null

# check if volumes already exist
volumes=$($engine volume ls)
for vol in "$wallet_volume_name" "$ledger_volume_name"
do
    if echo "$volumes" | grep -E ".*\s$vol$" > /dev/null; then
        print_error "a volume named $vol already exists"
        exit 1
    fi
done

# generate steward and node keys
echo -e "\n*** Steward information ***"
if [ -z "${steward_seed+x}" ]; then
    $engine run --rm -v $wallet_volume_name:/root/.indy_client indy-cli generate-keys "$pool_name" "$wallet_name" "$verbose"
else
    # pass the steward seed into the container
    # using a file to do so hides it from the process list
    echo "$steward_seed" > "./steward_seed"

    $engine run --rm -v $wallet_volume_name:/root/.indy_client -v ./steward_seed:/root/.indy_client/steward_seed indy-cli generate-keys "$pool_name" "$wallet_name" --seed-path=/root/.indy_client/steward_seed "$verbose"
fi

# check the exit code
if [ ! $? -eq 0 ]; then
    >&2 echo -e "\033[1;31mError:\033[0m failed to create wallet"
    exit 1
fi

# savely remove any seed data that has been used
if [ -f "./steward_seed" ]; then
    shred --remove=unlink "./steward_seed"
fi

# initialize validator node
echo -e "\n*** Node information ***"

if [ -z "${node_seed+x}" ]; then
    $engine run --rm -v $ledger_volume_name:/var/lib/indy validator init-node "$node_name" "$verbose"
else
    # pass the node seed into the container
    # using a file to do so hides it from the process list
    echo "$node_seed" > "./node_seed"

    $engine run --rm -v $ledger_volume_name:/var/lib/indy -v ./node_seed:/var/lib/indy/node_seed validator init-node "$node_name" --seed-path=/var/lib/indy/node_seed "$verbose"
fi

# check the exit code
if [ ! $? -eq 0 ]; then
    >&2 echo -e "\033[1;31mError:\033[0m failed to initialize node"
    exit 1
fi

# savely remove any seed data that has been used
if [ -f "./node_seed" ]; then
    shred --remove=unlink "./node_seed"
fi

echo -e "\n\033[1mSetup has been completed\033[0m"
