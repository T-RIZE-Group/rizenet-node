#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh

# this migration will:
# 1. update the avalanchego client version
# 2. update the subnet-evm binary version

# export the avalanchego client so it can be used in this script:
export AVALANCHE_GO_VERSION="v1.13.0-fuji"
# export SUBNET_EVM_VERSION="0.7.2"


# update the subnet-evm binary and also make a backup of the current subnet-evm binary
sudo -E -u "$USER_NAME" bash -c "

  echo ''
  echo ''
  echo ''
  echo ''
  echo ''
  echo ''
  echo 'Listing the environment variables:'
  echo ''
  echo 'USER_NAME: $USER_NAME'
  echo 'RIZENET_DATA_DIR: $RIZENET_DATA_DIR'
  echo 'SUBNET_EVM_VERSION: $SUBNET_EVM_VERSION'
  echo 'SUBNET_VM_ID: $SUBNET_VM_ID'
  echo 'BACKUPS_FOLDER: $BACKUPS_FOLDER'

  echo 'running @@@cd $RIZENET_DATA_DIR/plugins@@@'
  cd '$RIZENET_DATA_DIR/plugins'

  echo 'running @@@wget -q https://github.com/ava-labs/subnet-evm/releases/download/v${SUBNET_EVM_VERSION}/subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz@@@'
  wget -q 'https://github.com/ava-labs/subnet-evm/releases/download/v${SUBNET_EVM_VERSION}/subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz' && \
  echo 'Download of subnet-evm succeeded' || echo 'Download of subnet-evm failed'

  echo 'running @@@tar xf subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz@@@'
  tar xf 'subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz'
  echo 'running @@@rm README.md LICENSE subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz@@@'
  rm README.md LICENSE 'subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz'

  echo 'running @@@mv $SUBNET_VM_ID ${BACKUPS_FOLDER}/backup_of_${SUBNET_VM_ID}_before_${SUBNET_EVM_VERSION}_2@@@'
  mv $SUBNET_VM_ID '${BACKUPS_FOLDER}/backup_of_${SUBNET_VM_ID}_before_${SUBNET_EVM_VERSION}_2'

  echo 'running @@@mv subnet-evm $SUBNET_VM_ID@@@'
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


# update the migration version in the migration file
export MIGRATION_ID=2
sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE"

echo
echo
echo
echo
echo "Done executing migration 2 on your Rizenet node!"
echo
