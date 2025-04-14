#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh
# exactly as described in https://docs.rizenet.io/docs/rizenet/Rizenet%20Blockchain/validators/node_updating

# this migration will:
# 1. update the avalanchego client version
# 2. update the subnet-evm binary version

# export the avalanchego client so it can be used in this script:
export AVALANCHE_GO_VERSION="v1.13.0-fuji"
export SUBNET_EVM_VERSION="0.7.2"

# update the value for the avalanchego version on the config of the node:
sed -i 's/^export AVALANCHE_GO_VERSION=.*/export AVALANCHE_GO_VERSION="v1.13.0-fuji"/' "$SCRIPT_DIR/myNodeConfig.sh"

# update the value for the subnet-evm version on the config of the node:
sed -i 's/^export SUBNET_EVM_VERSION=.*/export SUBNET_EVM_VERSION="0.7.2"/' "$SCRIPT_DIR/myNodeConfig.sh"

# stop the currently running avalanchego client
sudo systemctl stop avalanchego

# Build the node client as the regular user
sudo -E -u "$USER_NAME" bash -c "
  export PATH=/usr/local/go/bin:\$PATH
  cd '$RIZENET_DATA_DIR/avalanchego'
  git checkout -q master
  git reset --hard -q
  git pull -q
  git checkout -q '$AVALANCHE_GO_VERSION'
  $RIZENET_DATA_DIR/avalanchego/scripts/build.sh
"

# update the subnet-evm binary and also make a backup of the current subnet-evm binary
sudo -E -u "$USER_NAME" bash -c "
  cd '$RIZENET_DATA_DIR/plugins'

  wget -q 'https://github.com/ava-labs/subnet-evm/releases/download/v${SUBNET_EVM_VERSION}/subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz' && \
  echo 'Download of subnet-evm succeeded' || echo 'Download of subnet-evm failed'

  tar xf 'subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz'
  rm README.md LICENSE 'subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz'

  mv $SUBNET_VM_ID '${BACKUPS_FOLDER}/backup_of_${SUBNET_VM_ID}_before_${SUBNET_EVM_VERSION}'

  mv subnet-evm $SUBNET_VM_ID
"

# start/restart the avalanchego service
echo "Restarting avalanche go service..."
sleep 5
sudo systemctl restart avalanchego
sleep 10

# show if it is running correctly:
echo "printing status of avalanchego service:"
sudo systemctl status avalanchego --no-pager


echo
echo

# check if the upgrade was a success:
curl -H 'Content-Type: application/json' --data "{
    \"jsonrpc\":\"2.0\",
    \"id\"     :1,
    \"method\" :\"health.health\",
    \"params\": {
        \"tags\": [\"$SUBNET_ID\"]
    }
}" "http://localhost:$RPC_PORT/ext/health"
# TODO: check if healthy value in the response is true...


echo
echo

# check if the versions are correctly listed
curl -X POST --data '{
    "jsonrpc":"2.0",
    "id"     :1,
    "method" :"info.getNodeVersion"
}' -H 'content-type:application/json;' 127.0.0.1:$RPC_PORT/ext/info

echo
echo
