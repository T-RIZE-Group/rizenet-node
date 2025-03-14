#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh

# this migration will:
# 1. install the node monitoring software


# show if the avalanchego client is running correctly:
echo "printing status of avalanchego service:"
sudo systemctl status avalanchego --no-pager


echo
echo

# check if the node is spinning smoothly:
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
export MIGRATION_ID=3
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
source ./monitoring-installer.sh --1
# wait a bit and print information to check if it's running:
echo "Sleeping for 10 then printing status of prometheus:"
sleep 10
sudo systemctl status prometheus --no-pager


# Install grafana on the node
echo "Install Grafana on the node..."
source ./monitoring-installer.sh --2
# wait a bit and print information to check if it's running:
echo "Sleeping for 10 then printing status of grafana:"
sleep 10
sudo systemctl status grafana-server --no-pager


# install the node_exporter prometheus plugin that collects extra metrics:
echo "Install node_exporter prometheus plugin on the node..."
source ./monitoring-installer.sh --3
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
source ./monitoring-installer.sh --4
echo "Sleeping for 10 before going on:"
sleep 10


# install additional dashboards:
echo "Installing additional dashboards for grafana on the node..."
source ./monitoring-installer.sh --5
echo "Sleeping for 10 before going on:"
sleep 10


echo
echo
echo
echo
echo "Done executing migration 3 on your Rizenet node!"
echo
