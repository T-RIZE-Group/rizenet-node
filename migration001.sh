#!/bin/bash

# update the value for the avalanchego version on the config of the node:
sed -i 's/^export AVALANCHE_GO_VERSION=.*/export AVALANCHE_GO_VERSION="v1.12.0-fuji"/' "$SCRIPT_DIR/myNodeConfig.sh"


# update the value for the subnet-evm version on the config of the node:
sed -i 's/^export SUBNET_EVM_VERSION=.*/export SUBNET_EVM_VERSION="0.6.12"/' "$SCRIPT_DIR/myNodeConfig.sh"

# export the avalanchego client so it can be used in this script:
export AVALANCHE_GO_VERSION="v1.12.0-fuji"

# stop the currently running avalanchego client
sudo systemctl stop avalanchego

# Build the node client as the regular user
sudo -u "$USER_NAME" bash -c "
  cd '$RIZENET_DATA_DIR/avalanchego'
  git reset --hard
  git pull
  git checkout '$AVALANCHE_GO_VERSION'
  $RIZENET_DATA_DIR/avalanchego/scripts/build.sh
"


# update the subnet-evm binary and also make a backup of the current subnet-evm binary
sudo -u "$USER_NAME" bash -c "
  cd '$RIZENET_DATA_DIR/plugins'

  wget "https://github.com/ava-labs/subnet-evm/releases/download/v${SUBNET_EVM_VERSION}/subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz"
  tar xvf "subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz"
  rm README.md LICENSE "subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz"

  mv $SUBNET_VM_ID "./backup_of_${SUBNET_VM_ID}_before_${SUBNET_EVM_VERSION}"

  mv subnet-evm $SUBNET_VM_ID
"


if [ "$ENABLE_AUTOMATED_UBUNTU_SECURITY_UPDATES" = "true" ]; then
  # Install unattended-upgrades
  sudo apt install unattended-upgrades -y

  # Enable automatic updates via dpkg-reconfigure
  sudo dpkg-reconfigure --priority=low unattended-upgrades

  # Ensure that automatic updates are enabled in /etc/apt/apt.conf.d/20auto-upgrades
  sudo bash -c 'cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
  APT::Periodic::Update-Package-Lists "1";
  APT::Periodic::Unattended-Upgrade "1";
  EOF'

  # Optionally, adjust /etc/apt/apt.conf.d/50unattended-upgrades to include any additional settings
  # For example, enable updates from ${distro_id}:${distro_codename}-updates
  sudo sed -i 's|^//\s*"\${distro_id}:\${distro_codename}-updates";|"\${distro_id}:\${distro_codename}-updates";|' /etc/apt/apt.conf.d/50unattended-upgrades

  # Restart the unattended-upgrades service
  sudo systemctl restart unattended-upgrades
fi


# all the code below is to add explicity values to the config for "log-rotater-max-size" and "log-rotater-max-files":
if [ "$HAS_DYNAMIC_IP" = "true" ]; then
  publicIp='' #empty because on a dynamic IP this changes all the time
  publicIpResolutionService='"public-ip-resolution-service": "ifconfigCo",' # use a service to resolve the dynamic IP
else
  publicIp='"public-ip": "'$(curl -s ifconfig.me | tr -d '[:space:]')'",'
  publicIpResolutionService='' # no dynamic IP resolution service needed
fi

# variables that currently are the same for all nodes, but in the future will change based on the network optimizations:
httpHost='"0.0.0.0"'
allowedHosts='["*"]'
allowedOrigins='["*"]'
trackSubnets=$SUBNET_ID

# write config file
sudo -u "$USER_NAME" tee "$RIZENET_DATA_DIR/configs/avalanchego/config.json" > /dev/null <<EOF
{
  "http-allowed-hosts": $allowedHosts,
  "http-allowed-origins": $allowedOrigins,
  "http-host": $httpHost,

  $publicIp
  $publicIpResolutionService

  "track-subnets": "$trackSubnets",
  "data-dir": "$RIZENET_DATA_DIR",
  "network-id": "$NETWORK_ID",
  "http-port": $RPC_PORT,
  "staking-port": $P2P_PORT,

  "log-rotater-max-size": $LOG_ROTATER_MAX_SIZE,
  "log-rotater-max-files": $LOG_ROTATER_MAX_FILES
}
EOF

# restart the avalanchego service
sudo systemctl restart avalanchego
sleep 5

# show if it is running correctly:
sudo systemctl status avalanchego --no-pager


echo
echo

# check if the upgrade was a success:
curl -H 'Content-Type: application/json' --data "{
    'jsonrpc':'2.0',
    'id'     :1,
    'method' :'health.health',
    'params': {
        'tags': ['11111111111111111111111111111111LpoYY', '$SUBNET_ID']
    }
}" "http://localhost:$RPC_PORT/ext/health"
# check if healthy value in the response is true...

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
export MIGRATION_ID=1
sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE"