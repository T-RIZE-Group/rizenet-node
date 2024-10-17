#!/bin/bash

# set to true if your node does not have a static IP:
export HAS_DYNAMIC_IP="false"

# change these ports if you have reason to do so:
export P2P_PORT="9651"
export RPC_PORT="9650"

# whether to create or not an 8GB swap file for the node. Recommended if you have less than 16GB of RAM.
export CREATE_SWAP_FILE="false"

# whether to change your system settings or not to limit the space used by log files
export LIMIT_LOG_FILES_SPACE="true"

export USER_NAME=${SUDO_USER:-$(whoami)}
export GROUP_NAME=$(id -gn ${SUDO_USER:-$(whoami)})
export USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
export HOME="$USER_HOME"
# change the folder where the data of the chain will be saved if you have reason to do so:
export RIZENET_DATA_DIR="/home/$USER_NAME/rizenetDataDir"
# the folder where have this script, the .dat file and the sidecar and genesis files:
export REPOSITORY_PATH="/home/$USER_NAME/rizenet-node"

# probably you would never need to change the variables below unless an admin tells you to do so:
export CHAIN_NAME="RizenetTestnet"
export GO_VERSION="1.22.8"
export AVALANCHE_GO_VERSION="v1.11.12"
export NETWORK_ID="fuji"
export AVALANCHE_NETWORK_FLAG="--fuji"
export SUBNET_ID="2oDeSiHzVCK9dEE22EDrYniG8V3Vr1CtfGNDCzMJwJR7Ttg8pr"
export CHAIN_ID="gs51JsazmyXrsFHL9dWUu1wPT9wgFt8BhLBFBLzNHkTkL4weS"
