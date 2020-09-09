# validator container
> Containerized indy validator node environment for the sovrin network

## General information
This container is a hyperledger indy node configured to be used in the Sovrin BuilderNet.

## Technologies
* Docker or Podman
* Ubuntu 16.04.7 LTS (Xenial Xerus) base image
* Wrapper for common tasks in Bash

## Usage

### Init node for BuilderNet
init-node is a wrapper that automates the initialization of the node for use in the BuilderNet. The resulting seed, verification node, BLS public key and BLS proof of possession will be output to stdout.
Using the `--seed` or `--seed-path` option allows the regeneration of a key pair from its seed.

```
docker run -v LOCAL_DIR:/var/lib/indy validator init-node NODE_NAME [ARG..]

Options:
    -s, --seed string           Use given seed instead of generating one
    -p, --seed-path file-path   Fetch the seed from a mounted file
    -v, --verbose               Print the output of init_indy_node`
```

### Run the node
Running the container without any CMD will automatically start the node. Please make sure to initialize your node first by using the init-node command as described above.

```
docker run -v LOCAL_DIR:/var/lib/indy -p 9701:9701,9702:9702 validator
```
