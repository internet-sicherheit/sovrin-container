#!/bin/bash

usage() {
    echo "
Usage:
    generate-keys POOL_NAME WALLET_NAME [ARG..]

Options:
    -s, --seed string           Use given seed instead of generating one
    -p, --seed-path file-path   Fetch the seed from a mounted file
    -h, --help                  Print this help message
    -v, --verbose               Print the output of indy-cli"
}

# checks if an argument exists or throws an error otherwise
check_argument() {
    if [ -z "$1" ]; then
        >&2 echo "$2"
        usage
        exit 22
    fi
}

# parse the command options using getopt
opts=$(getopt -o 'hvs:p:' --longoptions 'help,verbose,seed:,seed-path:' -n 'generate-keys' -- "$@")

# exit if getopt throws an error
if [ $? -ne 0 ]; then
    usage
    exit 1
fi

# apply the rearranged arguments
eval set -- "$opts"

# iterate over and parse the given flags
while true; do
    case "$1" in
        '-s'|'--seed')
            seed=$2
            shift 2
            continue
            ;;
        '-sp'|'--seed-path')
            seed_path=$2
            shift 2
            continue
            ;;
        '-v'|'--verbose')
            verbose=true
            shift
            continue
            ;;
        '-h'|'--help')
            usage
            exit 0
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

# verify that all required arguments are present
check_argument "$1" "Missing pool name argument"
check_argument "$2" "Missing wallet name argument"

# assign proper variable names to the arguments
pool_name=$1
wallet_name=$2

# check that only one seed fetch mechanism is specified
if [ ! -z "${seed+x}" ] && [ ! -z "${seed_path}" ]; then
    >&2 echo "Error: ambiguous seed argument. --seed and --seed-path cannot be used together"
    exit 22
fi

# try to fetch a seed from filesystem if none was directly given
if [ -z "${seed+x}" ]; then
    # use default path if none was given
    if [ -z "${seed_path+x}" ]; then
        seed_path="/var/lib/indy/seed"
    fi

    if [ -f "$seed_path" ]; then
        # read the seed from a user supplied file
        seed=$(tr -d '\n' < "$seed_path")
    else
        # randomly generate a seed if none was given
        seed=$(pwgen -s 32 1)
    fi
fi

# verify the seed length
if [ ${#seed} != 32 ]; then
    >&2 echo "Error: incorrect seed size. Expected 32 but got ${#seed}"
    exit 22
fi

# generate wallet encryption key
wallet_key=$(pwgen -s 32 1)

# save all indy commands in a batch file for noninteractive use in the cli
cat << EOF >> batch_file
pool create $pool_name gen_txn_file=pool_transactions_builder_genesis
wallet create $wallet_name key=$wallet_key
pool connect $pool_name
wallet open $wallet_name key=$wallet_key
did new seed=$seed
exit
EOF

echo "Generating keys..."

# run batch file commands in the CLI
if [ ! -z "${verbose+x}" ]; then
    indy-cli --config /etc/indy-cli/cliconfig.json batch_file | tee output
else
    indy-cli --config /etc/indy-cli/cliconfig.json batch_file > output
fi

# parse the DID and verkey from the indy-cli output
tmp=$(grep "Did \"" output | tr \" '\n')
did=$(echo "$tmp" | head -2 | tail -1)
verkey=$(echo "$tmp" | head -4 | tail -1)

echo -e "\033[1;31mAttention\033[39;1m
The seed and wallet key are very sensitive data and should be handled accordingly. Please store both in a secure manner.\033[0m\n"

echo -e "\033[1;31mSteward seed:\033[0m $seed
\033[1;31mWallet key:\033[0m $wallet_key
\033[1mDID:\033[0m $did
\033[1mverkey:\033[0m $verkey"

# shred batch and output file to remove any sensible data in case the container lingers
shred --remove=unlink batch_file
shred --remove=unlink output

exit 0
