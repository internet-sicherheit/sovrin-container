# indy-cli container
> Containerized indy-cli environment to interact with the sovrin network

## General information
This container is an interface for the hyperledger indy-cli client allowing both direct access as well as a CLI like wrapper to perform common tasks.

## Technologies
* Docker or Podman
* Ubuntu 18.04.5 LTS (Bionic Beaver) base image
* Wrapper for common tasks in Bash

## Usage

### Generate new key pair
generate-keys is a wrapper that automates the creation of a new key pair. The resulting seed, wallet key, DID and verykey will be output to stdout.
Using the `--seed` or `--seed-path` option allows the regeneration of a key pair from its seed.

```
docker run -it indy-cli generate-keys POOL_NAME WALLET_NAME [ARG..]

Options:
    -s, --seed string           Use given seed instead of generating one
    -p, --seed-path file-path   Fetch the seed from a mounted file
    -v, --verbose               Print the output of indy-cli`
```
### Direct indy-cli access
Directly opens the indy-cli command line interface

```
docker run -it indy-cli
```
