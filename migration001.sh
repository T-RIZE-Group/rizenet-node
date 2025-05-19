#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh
# exactly as described in https://docs.rizenet.io/docs/rizenet/Rizenet%20Blockchain/validators/node_updating

# # update the value for the avalanchego version on the config of the node:
# sed -i 's/^export AVALANCHE_GO_VERSION=.*/export AVALANCHE_GO_VERSION="v1.12.0-fuji"/' "$SCRIPT_DIR/myNodeConfig.sh"

# # update the value for the subnet-evm version on the config of the node:
# sed -i 's/^export SUBNET_EVM_VERSION=.*/export SUBNET_EVM_VERSION="0.6.12"/' "$SCRIPT_DIR/myNodeConfig.sh"

# # export the avalanchego client and EVM version so they can be used in this script:
# export AVALANCHE_GO_VERSION="v1.12.0-fuji"
# export SUBNET_EVM_VERSION="0.6.12"

# # stop the currently running avalanchego client
# sudo systemctl stop avalanchego

# # Build the node client as the regular user
# sudo -u "$USER_NAME" bash -c "
#   echo "Pulling the new version of avalanchego and building it - $AVALANCHE_GO_VERSION"
#   export PATH=/usr/local/go/bin:\$PATH
#   cd '$RIZENET_DATA_DIR/avalanchego'
#   git checkout -q master
#   git reset --hard -q
#   git pull -q
#   git checkout -q '$AVALANCHE_GO_VERSION'
#   $RIZENET_DATA_DIR/avalanchego/scripts/build.sh
# "

# # update the subnet-evm binary and also make a backup of the current subnet-evm binary
# sudo -u "$USER_NAME" bash -c "
#   echo "Downloading and installing new EVM version $SUBNET_EVM_VERSION"
#   cd '$RIZENET_DATA_DIR/plugins'

#   wget -q 'https://github.com/ava-labs/subnet-evm/releases/download/v${SUBNET_EVM_VERSION}/subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz' && \
#   echo 'Download of subnet-evm succeeded' || echo 'Download of subnet-evm failed'

#   tar xf 'subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz'
#   rm README.md LICENSE 'subnet-evm_${SUBNET_EVM_VERSION}_linux_amd64.tar.gz'

#   mv $SUBNET_VM_ID '${BACKUPS_FOLDER}/backup_of_${SUBNET_VM_ID}_before_${SUBNET_EVM_VERSION}'

#   mv subnet-evm $SUBNET_VM_ID
# "


if [ "$ENABLE_AUTOMATED_UBUNTU_SECURITY_UPDATES" = "true" ]; then
  # Install unattended-upgrades
  sudo apt-get install unattended-upgrades -y -q

  # Enable automatic updates via dpkg-reconfigure
  sudo dpkg-reconfigure --priority=medium unattended-upgrades

  # Ensure that automatic updates are enabled in /etc/apt/apt.conf.d/20auto-upgrades
  printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null

  # Optionally, adjust /etc/apt/apt.conf.d/50unattended-upgrades to include any additional settings
  # For example, enable updates from ${distro_id}:${distro_codename}-updates
  sudo sed -i 's|^//\s*"\${distro_id}:\${distro_codename}-updates";|"\${distro_id}:\${distro_codename}-updates";|' /etc/apt/apt.conf.d/50unattended-upgrades

  # Restart the unattended-upgrades service
  sudo systemctl restart unattended-upgrades
  sleep 5
fi


# all the code below is to add explicity values to the config for "log-rotater-max-size" and "log-rotater-max-files":
if [ "$HAS_DYNAMIC_IP" = "true" ]; then
  publicIp='' #empty because on a dynamic IP this changes all the time
  publicIpResolutionService='"public-ip-resolution-service": "ifconfigCo",' # use a service to resolve the dynamic IP
  publicIpResolutionFrequency='"public-ip-resolution-frequency": "1m0s",'

  # both ifconfigCo and opendns can return an IPv6 address, which is not supported by Avalanche.
  # for this reason, we must disable IPv6 on nodes with dynamic IP:
  # Function: update or add a sysctl setting
  update_sysctl_setting() {
      local setting="$1"  # e.g., net.ipv6.conf.all.disable_ipv6
      local value="$2"    # e.g., 1
      local line="${setting} = ${value}"

      # Check if the setting already exists
      if grep -q "^${setting}" "/etc/sysctl.conf"; then
          # Replace the line with the correct value if it's different
          sudo sed -i "s|^${setting}.*|${line}|g" "/etc/sysctl.conf"
      else
          # Append the setting if not found
          echo "${line}" | sudo tee -a "/etc/sysctl.conf" > /dev/null
      fi
  }

  # Update the IPv6 disabling settings
  update_sysctl_setting "net.ipv6.conf.all.disable_ipv6" "1"
  update_sysctl_setting "net.ipv6.conf.default.disable_ipv6" "1"

  # Reload sysctl settings
  sudo sysctl -p

else
  publicIp='"public-ip": "'$(curl -s -4 ifconfig.co | tr -d '[:space:]')'",'
  publicIpResolutionService='' # no dynamic IP resolution service needed
  publicIpResolutionFrequency=''
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
  $publicIpResolutionFrequency

  "track-subnets": "$trackSubnets",
  "data-dir": "$RIZENET_DATA_DIR",
  "network-id": "$NETWORK_ID",
  "http-port": $RPC_PORT,
  "staking-port": $P2P_PORT,

  "log-rotater-max-size": $LOG_ROTATER_MAX_SIZE,
  "log-rotater-max-files": $LOG_ROTATER_MAX_FILES
}
EOF

# Write the JSON content to upgrade.json to set the upgrade
# to Wed Nov 27 2024 17:00:00 GMT+0000
cat <<EOF > "$RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/upgrade.json"
{
  "networkUpgradeOverrides": {
    "etnaTimestamp": 1732726800
  }
}
EOF

# start/restart the avalanchego service
sleep 5

sudo systemctl restart avalanchego
sleep 5

# show if it is running correctly:
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
