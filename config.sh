#!/bin/bash

# set to true if your node does not have a static IP:
export HAS_DYNAMIC_IP="false"

# change these ports if you have reason to do so:
export P2P_PORT="9651"
export RPC_PORT="9650"

# whether to create or not an 8GB swap file for the node.
# Recommended if you have less than 16GB of RAM:
export CREATE_SWAP_FILE="false"

# whether to change your system settings or not to limit the space used by log files:
export LIMIT_LOG_FILES_SPACE="true"

# whether to enable Ubuntu to automatically install security updates:
export ENABLE_AUTOMATED_UBUNTU_SECURITY_UPDATES="true"

# some variables that are filled by reading from your system:
export USER_NAME=${SUDO_USER:-$(whoami)}
export GROUP_NAME=$(id -gn ${SUDO_USER:-$(whoami)})
export USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
export HOME="$USER_HOME"

# change the folder where the data of the chain will be saved if you have reason to do so:
export RIZENET_DATA_DIR="/home/$USER_NAME/rizenetDataDir"

# the folder containing this script, the .dat file and the sidecar and genesis files:
export REPOSITORY_PATH="/home/$USER_NAME/rizenet-node"

# folder where multiple stuff is backuped before sensitive operations:
export BACKUPS_FOLDER="/home/$USER_NAME/rizenet-node-backups"

# configure the space occupied by logs of the AvalancheGO client:
export LOG_ROTATER_MAX_SIZE="16"
export LOG_ROTATER_MAX_FILES="21"

# when trying to upload files to file sharing services, how long to wait
# before trying the next service:
export UPLOAD_TIMEOUT_IN_SECONDS="5"

# probably you would never need to change the variables below unless an
# admin tells you to do so:
export CHAIN_NAME="RizenetTestnet"
export GO_VERSION="1.22.8"
export AVALANCHE_GO_VERSION="v1.13.0-fuji"
export SUBNET_EVM_VERSION="0.7.2"
export NETWORK_ID="fuji"
export AVALANCHE_NETWORK_FLAG="--fuji"
export SUBNET_ID="2oDeSiHzVCK9dEE22EDrYniG8V3Vr1CtfGNDCzMJwJR7Ttg8pr"
export CHAIN_ID="gs51JsazmyXrsFHL9dWUu1wPT9wgFt8BhLBFBLzNHkTkL4weS"
export SUBNET_VM_ID="dJ74gDeqGpbnqkpeuK9SaGK1Uuhgaxe7YmQvLA7nCiLBXa7kW"

# node monitoring:
export GRAFANA_PORT="3000"
export NODE_EXPORTER_SERVICE_FILE_PATH="/etc/systemd/system/node_exporter.service"
export DEFAULT_JSON_EXPORTER_PORT=7979
export DEFAULT_NODE_EXPORTER_PORT=9100


# after editing the config to adapt it to your node, set IS_CONFIG_READY to "true" in the
# file myNodeConfig.sh, indicating you reviewed and updated your node config accordingly:
export IS_CONFIG_READY="false"

