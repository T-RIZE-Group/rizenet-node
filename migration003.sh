#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh
# exactly as described in https://docs.rizenet.io/docs/rizenet/Rizenet%20Blockchain/validators/node_updating

# this migration will:
# 1. install the node monitoring software


# show if the avalanchego client is running correctly:
echo "printing status of avalanchego service:"
sudo systemctl status avalanchego --no-pager


echo
echo
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
echo
echo





# Check if myNodeConfig.sh already contains a line with PROMETEHUS_VERSION=
if ! grep -q '^export PROMETEHUS_VERSION=' "$SCRIPT_DIR/myNodeConfig.sh"; then
  # Append the new version line if not found
  echo '' >> "$SCRIPT_DIR/myNodeConfig.sh"
  echo '# node monitoring:' >> "$SCRIPT_DIR/myNodeConfig.sh"
  echo 'Adding PROMETEHUS_VERSION="2.55.1" to $SCRIPT_DIR/myNodeConfig.sh'
  echo 'export PROMETEHUS_VERSION="2.55.1"' >> "$SCRIPT_DIR/myNodeConfig.sh"
fi

# Check if myNodeConfig.sh already contains a line with GRAFANA_PORT=
if ! grep -q '^export GRAFANA_PORT=' "$SCRIPT_DIR/myNodeConfig.sh"; then
  echo 'Adding GRAFANA_PORT="3000" to $SCRIPT_DIR/myNodeConfig.sh'
  echo 'export GRAFANA_PORT="3000"' >> "$SCRIPT_DIR/myNodeConfig.sh"
  echo '' >> "$SCRIPT_DIR/myNodeConfig.sh"
fi





##### NODE MONITORING: prometheus + grafana #####

# install the node monitoring service (prometheus + grafana)
# Source the myNodeConfig.sh file from the same directory
echo "loading myNodeConfig.sh"
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")
echo "Sourcing config from $SCRIPT_DIR/myNodeConfig.sh"
source "$SCRIPT_DIR/myNodeConfig.sh"


# Install Prometheus on the node
echo "Install Prometheus on the node..."
source $SCRIPT_DIR/monitoring-installer.sh --1
# wait a bit and print information to check if it's running:
echo "Sleeping for 10 then printing status of prometheus:"
sleep 10
sudo systemctl status prometheus --no-pager


# Install grafana on the node
echo "Install Grafana on the node..."
source $SCRIPT_DIR/monitoring-installer.sh --2
# wait a bit and print information to check if it's running:
echo "Sleeping for 10 then printing status of grafana:"
sleep 10
sudo systemctl status grafana-server --no-pager


# install the node_exporter prometheus plugin that collects extra metrics:
echo "Install node_exporter prometheus plugin on the node..."
source $SCRIPT_DIR/monitoring-installer.sh --3
# wait a bit and print information to check if it's running:
echo "Sleeping for 10 then printing status of node_exporter:"
sleep 10
sudo systemctl status node_exporter --no-pager


# install the avalanche dashboards:
echo "Installing avalanche dashboard for grafana on the node..."
source $SCRIPT_DIR/monitoring-installer.sh --4
echo "Sleeping for 10 before going on:"
sleep 10


# install additional dashboards:
echo "Installing additional dashboards for grafana on the node..."
source $SCRIPT_DIR/monitoring-installer.sh --5
echo "Sleeping for 10 before going on:"
sleep 10


