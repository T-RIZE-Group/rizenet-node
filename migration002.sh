#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh

# this migration will:
# 1. update the avalanchego client version
# 2. update the subnet-evm binary version
# 3. install the node monitoring software

# export the avalanchego client so it can be used in this script:
export AVALANCHE_GO_VERSION="v1.13.0-fuji"

# update the value for the avalanchego version on the config of the node:
sed -i 's/^export AVALANCHE_GO_VERSION=.*/export AVALANCHE_GO_VERSION="v1.13.0-fuji"/' "$SCRIPT_DIR/myNodeConfig.sh"

# update the value for the subnet-evm version on the config of the node:
sed -i 's/^export SUBNET_EVM_VERSION=.*/export SUBNET_EVM_VERSION="0.7.2"/' "$SCRIPT_DIR/myNodeConfig.sh"

sudo -v

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
sudo systemctl restart avalanchego
sleep 5

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



##### NODE MONITORING: prometheus + grafana #####

# install the node monitoring service (prometheus + grafana)
# Source the myNodeConfig.sh file from the same directory
echo "loading myNodeConfig.sh"
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")
echo "Sourcing config from $SCRIPT_DIR/myNodeConfig.sh"
source "$SCRIPT_DIR/myNodeConfig.sh"


# disable questions during the setup:
echo "disabling questions during installation of node monitoring software"
sed -i 's/sudo apt-get install /sudo DEBIAN_FRONTEND=noninteractive apt-get install /g' monitoring-installer.sh

# Install Prometheus on the node
echo "Install Prometheus on the node..."
sudo -E -u "$USER_NAME" bash -c "
  source ./monitoring-installer.sh --1
"
# wait a bit and print information to check if it's running:
echo "Sleeping for 10 then printing status of prometheus:"
sleep 10
sudo systemctl status prometheus --no-pager


# Install grafana on the node
echo "Install Grafana on the node..."
sudo -E -u "$USER_NAME" bash -c "
  source ./monitoring-installer.sh --2
"
# wait a bit and print information to check if it's running:
echo "Sleeping for 10 then printing status of grafana:"
sleep 10
sudo systemctl status grafana-server --no-pager


# install the node_exporter prometheus plugin that collects extra metrics:
echo "Install node_exporter prometheus plugin on the node..."
sudo -E -u "$USER_NAME" bash -c "
  source ./monitoring-installer.sh --3
"
# wait a bit and print information to check if it's running:
echo "Sleeping for 10 then printing status of node_exporter:"
sleep 10
sudo systemctl status node_exporter --no-pager


# now that we installed the avalanche plugins, we edit the prometheus config
# to use our node port instead of the default one:
echo "switching port where prometheus is running, if node is on custom port ($RPC_PORT)"
sudo sed -i "s/9650/$RPC_PORT/" /etc/prometheus/prometheus.yml
sudo systemctl restart prometheus
echo "Sleeping for 10 then printing status of prometheus:"
sleep 10
echo "prometheus status:"
sudo systemctl status prometheus --no-pager


# install the avalanche dashboards:
echo "Installing avalanche dashboard for grafana on the node..."
sudo -E -u "$USER_NAME" bash -c "
  source ./monitoring-installer.sh --4
"
echo "Sleeping for 10 before going on:"
sleep 10


# install additional dashboards:
echo "Installing additional dashboards for grafana on the node..."
sudo -E -u "$USER_NAME" bash -c "
  source ./monitoring-installer.sh --5
"
echo "Sleeping for 10 before going on:"
sleep 10


echo
echo
echo
echo
echo "Done executing migration 2 on your Rizenet node!"
echo
