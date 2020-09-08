#!/bin/bash

usage() {
    echo "
Usage:
    init-node NODE_NAME [ARG..]

Options:
    -s, --seed string           Use given seed instead of generating one
    -p, --seed-path file-path   Fetch the seed from a mounted file
    -v, --verbose               Print verbose command output"
}

# checks if an argument exists or throws an error otherwise
check_argument() {
    if [ -z "$1" ]; then
        >&2 echo "$2"
        exit 22
    fi
}

# parse the command options using getopt
opts=$(getopt -o 'vs:p:' --longoptions 'verbose,seed:,seed-path:' -n 'init-node' -- "$@")

# exit if getopt throws an error
if [ $? -ne 0 ]; then
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
check_argument "$1" "Missing node name argument"

# assign proper variable names to the arguments
node_name=$1

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

    if [ -f $seed_path ]; then
        # read the seed from a user supplied file
        seed=$(tr -d '\n' < "$seed_path")
    fi
fi

# verify the seed length
if [ ! -z "${seed+x}" ] && [ ${#seed} != 32 ]; then
    >&2 echo "Error: incorrect seed size. Expected 32 but got ${#seed}"
    exit 22
fi

if [ ! -z "${verbose+x}" ]; then
    init_indy_node "$node_name" 0.0.0.0 9701 0.0.0.0 9702 "$seed" | tee output
else
    init_indy_node "$node_name" 0.0.0.0 9701 0.0.0.0 9702 "$seed" > output
fi

# parse output data
if [ -z "${seed+x}" ]; then
    seed=$(grep -i "random seed" output | awk -F"'" '{print $(NF-1)}')
fi
ver_key=$(grep -i "Verification key is" output | awk -F' ' '{print $NF}' | tail -n1)
bls_pub_key=$(grep -i "BLS Public key is" output | awk -F' ' '{print $NF}')
bls_pop=$(grep -i "Proof of possession for BLS key is" output | awk -F' ' '{print $NF}')

echo -e "\033[1;31mAttention\033[39;1m
The seed is sensitive data and should be handled accordingly in a secure manner. Your Node verification key and BLS key along with its POP are public and will be published on the ledger using the indy-cli.\033[0m\n"

echo -e "\033[1;31mSeed:\033[0m $seed
\033[1mVerification key:\033[0m $ver_key
\033[1mBLS public key:\033[0m $bls_pub_key
\033[1mBLS proof of possession:\033[0m $bls_pop"

# savely remove output file containing sensitive data
shred --remove=unlink output

# copy the environment file created by init_indy_node into the persistent volume for later use
cp /etc/indy/indy.env /var/lib/indy/indy.env

exit 0
