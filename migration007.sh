#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh
# exactly as described in https://docs.rizenet.io/docs/rizenet/Rizenet%20Blockchain/validators/node_updating

# this migration will:
# 1. update the avalanchego client version
# 2. update the subnet-evm binary version



##### add default grafana password if absent #####
# might not have been executed from migration 3, so we add it back here in migration 7:
GRAFANA_CONFIG_FILE="/etc/grafana/grafana.ini"
# Function to generate a secure random password
generate_password() {
  openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c16
}
# Read the existing password from your config (assuming a line like: INITIAL_GRAFANA_ADMIN_PASSWORD=yourpassword)
EXISTING_PASSWORD=$(grep '^export INITIAL_GRAFANA_ADMIN_PASSWORD=' "$SCRIPT_DIR/myNodeConfig.sh" | cut -d'=' -f2 | tr -d ' ')

# Check if password exists
if [ -z "$EXISTING_PASSWORD" ]; then
  echo "No existing password found. Generating a new one..."
  PASSWORD=$(generate_password)

  # Update your custom config
  if grep -q '^export INITIAL_GRAFANA_ADMIN_PASSWORD=' "$SCRIPT_DIR/myNodeConfig.sh"; then
    echo "Found INITIAL_GRAFANA_ADMIN_PASSWORD"
    sed -i "s/^export INITIAL_GRAFANA_ADMIN_PASSWORD=.*/export INITIAL_GRAFANA_ADMIN_PASSWORD=$PASSWORD/" "$SCRIPT_DIR/myNodeConfig.sh"
  else
    echo "export INITIAL_GRAFANA_ADMIN_PASSWORD=$PASSWORD" >> "$SCRIPT_DIR/myNodeConfig.sh"
  fi

  echo "Updated password in $SCRIPT_DIR/myNodeConfig.sh."
else
  echo "Existing password found. Reusing it."
  PASSWORD=$EXISTING_PASSWORD
fi

# Now update Grafana's grafana.ini
echo "Updating Grafana config..."
sudo sed -i "s/^;*\s*admin_password\s*=.*/admin_password = $PASSWORD/" "$GRAFANA_CONFIG_FILE"

echo "Restarting Grafana server..."
sudo systemctl restart grafana-server

echo "Done! Current Grafana admin password: $PASSWORD"
##### add default grafana password if absent #####



# export the avalanchego client so it can be used in this script:
export AVALANCHE_GO_VERSION="v1.14.0-fuji"
export SUBNET_EVM_VERSION="0.8.0"

# update the value for the avalanchego version on the config of the node:
sed -i 's/^export AVALANCHE_GO_VERSION=.*/export AVALANCHE_GO_VERSION="v1.14.0-fuji"/' "$SCRIPT_DIR/myNodeConfig.sh"

# update the value for the subnet-evm version on the config of the node:
sed -i 's/^export SUBNET_EVM_VERSION=.*/export SUBNET_EVM_VERSION="0.8.0"/' "$SCRIPT_DIR/myNodeConfig.sh"

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

  # extract:
  tar xf 'subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz'

  mv $SUBNET_VM_ID '${BACKUPS_FOLDER}/backup_of_${SUBNET_VM_ID}_before_${SUBNET_EVM_VERSION}'

  mv subnet-evm $SUBNET_VM_ID

  # There can only be one file in this folder, so delete everything except the plugin:
  find . -maxdepth 1 -type f ! -name '${SUBNET_VM_ID}' -delete
"

# start/restart the avalanchego service
echo "Restarting avalanche go service..."
sleep 5
sudo systemctl restart avalanchego

echo "sleeping fro 120 seconds"
sleep 120

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
