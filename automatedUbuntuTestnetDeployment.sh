#!/bin/bash

# Check if the script is being run with sudo by a normal user
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ] || [ "$SUDO_USER" = "root" ]; then
  echo "This script must be run with sudo by a normal user, not directly as root or without sudo." >&2
  exit 1
fi

# obtain the true path of where this script is installed:
export SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")

echo "Making $SCRIPT_DIR/myNodeConfig.sh executable...."
chmod +x $SCRIPT_DIR/myNodeConfig.sh

# verify and load the config:
echo "Executing checkNodeConfig.sh"
source "$SCRIPT_DIR/checkNodeConfig.sh"
# Check the return status of checkNodeConfig.sh and exit if it failed
if [ $? -eq 1 ]; then
  echo "Node config check failed, exiting..."
  exit 1
fi


# Load util functions (like upload_encrypted_data) to encrypt files and upload metadata
echo "Sourcing common functions from $SCRIPT_DIR/util.sh"
source "$SCRIPT_DIR/util.sh"


# Get the user's default shell
USER_SHELL=$(getent passwd "$USER_NAME" | cut -d: -f7)
# Determine the shell configuration file
if [[ $USER_SHELL =~ zsh ]]; then
  terminalFile="$USER_HOME/.zshrc"
else
  terminalFile="$USER_HOME/.bashrc"
fi

# Ensure the terminal file exists and is owned by the user
sudo -u "$USER_NAME" touch "$terminalFile"


if [ "$CREATE_SWAP_FILE" = "true" ]; then
  # Create a swap file and set the swappiness of the host OS to 5:
  echo "creating swap file"
  sudo fallocate -l 8G /swapfile
  sudo dd if=/dev/zero of=/swapfile bs=1M count=8192
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

  # Set swappiness value for the current session:
  sudo sysctl vm.swappiness=5

  # make it permanent by editing the config file:
  # File to be modified
  SYSCTL_CONF="/etc/sysctl.conf"
  SWAPPINESS_SETTING="vm.swappiness=5"

  # Check if the file already contains the swappiness setting
  if grep -q "^vm.swappiness=" "$SYSCTL_CONF"; then
    # Update the existing setting
    sudo sed -i "s/^vm.swappiness=.*/$SWAPPINESS_SETTING/" "$SYSCTL_CONF"
  else
    # Add the new setting to the end of the file
    echo "$SWAPPINESS_SETTING" | sudo tee -a "$SYSCTL_CONF"
  fi
fi


if [ "$LIMIT_LOG_FILES_SPACE" = "true" ]; then
  # the node can write too many logs. To avoid filling the disk,
  # limit space occupied by logs on the system:
  # Use sed to update the SystemMaxUse setting in journald.conf
  echo "Setting log limits of the server"
  sudo sed -i '/^#SystemMaxUse/s/^#//g' /etc/systemd/journald.conf # Uncomment the line if it is commented
  sudo sed -i '/^SystemMaxUse=/s/=.*/=500M/' /etc/systemd/journald.conf # Set the limit to 500M

  # If SystemMaxUse does not exist, append it to the file
  if ! grep -q '^SystemMaxUse=' /etc/systemd/journald.conf; then
      echo 'SystemMaxUse=500M' | sudo tee -a /etc/systemd/journald.conf > /dev/null
  fi

  # apply changes:
  sudo systemctl restart systemd-journald
fi


if [ "$ENABLE_AUTOMATED_UBUNTU_SECURITY_UPDATES" = "true" ]; then
  echo "Enabling automated ubuntu security updates"

  # Install unattended-upgrades
  sudo apt install unattended-upgrades -y

  # Enable automatic updates via dpkg-reconfigure
  sudo dpkg-reconfigure -fnoninteractive --priority=low unattended-upgrades

  # Ensure that automatic updates are enabled in /etc/apt/apt.conf.d/20auto-upgrades
  sudo bash -c 'echo "APT::Periodic::Update-Package-Lists \"1\";" > /etc/apt/apt.conf.d/20auto-upgrades'
  sudo bash -c 'echo "APT::Periodic::Unattended-Upgrade \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades'

  # Optionally, adjust /etc/apt/apt.conf.d/50unattended-upgrades to include any additional settings
  # For example, enable updates from ${distro_id}:${distro_codename}-updates
  sudo sed -i 's|^//\s*"\${distro_id}:\${distro_codename}-updates";|"\${distro_id}:\${distro_codename}-updates";|' /etc/apt/apt.conf.d/50unattended-upgrades

  # Restart the unattended-upgrades service
  sudo systemctl restart unattended-upgrades
fi


# Install dependencies:
export DEBIAN_FRONTEND=noninteractive
echo "Updating apt"
sudo apt update
echo "Updating system"
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
echo "Installing dependencies"
sudo DEBIAN_FRONTEND=noninteractive apt install -y gcc jq openssl curl


# go must be installed manually on ubuntu because the old version is on the repo
echo "Installing GO"
sudo apt purge -y golang-go
sudo rm -rf /usr/local/go
wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
rm go${GO_VERSION}.linux-amd64.tar.gz
# download foundry which comes with cast and install as the regular user:
sudo -u "$USER_NAME" bash -c 'curl -L https://foundry.paradigm.xyz | bash'


# Append the foundry bin path variable if it doesn't exist
grep -qxF "export PATH=\$PATH:$USER_HOME/.foundry/bin" "$terminalFile" || \
  echo "export PATH=\$PATH:$USER_HOME/.foundry/bin" | sudo -u "$USER_NAME" tee -a "$terminalFile"


# Check and append the go path variable if it doesn't exist
grep -qxF 'export PATH=$PATH:/usr/local/go/bin' "$terminalFile" || \
  echo 'export PATH=$PATH:/usr/local/go/bin' | sudo -u "$USER_NAME" tee -a "$terminalFile"


# Install Foundry and Cast as the user that is running this script with sudo
sudo -u "$USER_NAME" bash -c "$USER_HOME/.foundry/bin/foundryup"


# Install Avalanche CLI as the user
echo "Installing Avalanche CLI"
sudo -u "$USER_NAME" bash -c 'curl -sSfL https://raw.githubusercontent.com/ava-labs/avalanche-cli/main/scripts/install.sh | sh -s'


# Append the avalanche-cli path variable to .bashrc and .zshrc for future sessions
grep -qxF "export PATH=\$PATH:$USER_HOME/bin" "$terminalFile" || \
  echo "export PATH=\$PATH:$USER_HOME/bin" | sudo -u "$USER_NAME" tee -a "$terminalFile"


# Create a folder at home for the node client
echo "Building the node client"
sudo -u "$USER_NAME" mkdir -p "$RIZENET_DATA_DIR"

# Build the node client as the regular user
sudo -u "$USER_NAME" bash -c "
  export PATH=/usr/local/go/bin:\$PATH
  cd '$RIZENET_DATA_DIR/'
  git clone https://github.com/ava-labs/avalanchego.git
  cd '$RIZENET_DATA_DIR/avalanchego'
  git checkout '$AVALANCHE_GO_VERSION'
  $RIZENET_DATA_DIR/avalanchego/scripts/build.sh
"

# Create the migration, which tracks the current version of the node and
# facilitates upgrades.Always launch a new node with the migration set
# to 0, to force running all migrations to bring it to the latest version:
echo "Creating migration file"
MIGRATION_FILE="$SCRIPT_DIR/migration"
if [ ! -f "$MIGRATION_FILE" ]; then
  sudo -u "$USER_NAME" bash -c "
    echo '0' > '$MIGRATION_FILE'
  "
fi

echo "Creating avalanchego node configuration file"
sudo -u "$USER_NAME" mkdir -p "$RIZENET_DATA_DIR/configs/avalanchego"


if [ "$HAS_DYNAMIC_IP" = "true" ]; then
  # don't include the publicIp variable, because on a node with dynamic IP this changes:
  publicIp=''

  # We use a service to resolve the dynamic public IP. When this value is provided,
  # the node will use that service to periodically resolve/update its public IP.
  # Only acceptable values are ifconfigCo, opendns:
  publicIpResolutionService='"public-ip-resolution-service": "ifconfigCo",'

  # Change the public IP update frequency from the default of 5 minutes to 1 minute:
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
  # get the public external IP, forcing it to be IPv4 with `-4`:
  publicIp='"public-ip": "'$(curl -s -4 ifconfig.co | tr -d '[:space:]')'",'

  # no dynamic IP resolution service needed:
  publicIpResolutionService=''
  publicIpResolutionFrequency=''
fi

# variables that currently are the same for all nodes, but can change based on the network optimizations:
httpHost='"0.0.0.0"'
allowedHosts='["*"]'
allowedOrigins='["*"]'
trackSubnets=$SUBNET_ID

# write config file
echo "Writing config file $RIZENET_DATA_DIR/configs/avalanchego/config.json"
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


echo "Creating a service for the node"
sudo tee /etc/systemd/system/avalanchego.service > /dev/null <<EOF
[Unit]
Description=AvalancheGo systemd service
After=network.target
[Service]
Type=simple
User=$USER_NAME
Group=$GROUP_NAME
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
WorkingDirectory=$RIZENET_DATA_DIR
ExecStart=$RIZENET_DATA_DIR/avalanchego/build/avalanchego --config-file "$RIZENET_DATA_DIR/configs/avalanchego/config.json"
LimitNOFILE=32768
[Install]
WantedBy=multi-user.target
EOF


echo
echo

echo "Copying chain description files (genesis.json and sidecar.json)"
sudo -u "$USER_NAME" mkdir -p "$USER_HOME/.avalanche-cli/subnets/${CHAIN_NAME}"
sudo -u "$USER_NAME" cp "$REPOSITORY_PATH/genesis${CHAIN_NAME}.json" "$USER_HOME/.avalanche-cli/subnets/${CHAIN_NAME}/genesis.json"
sudo -u "$USER_NAME" cp "$REPOSITORY_PATH/sidecar${CHAIN_NAME}.json" "$USER_HOME/.avalanche-cli/subnets/${CHAIN_NAME}/sidecar.json"


# create a folder and a file for the config file
echo "Creating the chain configuration files at:"
echo "  $RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json"
echo "  $RIZENET_DATA_DIR/configs/chains/C/config.json"
echo ""
sudo -u "$USER_NAME" mkdir -p "$RIZENET_DATA_DIR/configs/chains/$CHAIN_ID"
sudo -u "$USER_NAME" mkdir -p "$RIZENET_DATA_DIR/configs/chains/C"


# below, at the values for "eth-apis" that will be used by tee.
# currently just enabling all API in all validators:
ethAPIs='"eth",
    "eth-filter",
    "net",
    "web3",
  "internal-eth",
  "internal-blockchain",
  "internal-transaction",
  "debug-tracer",
  "internal-tx-pool"
'


# create the subnet chain config:
echo "Creating subnet chain config file $RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json"
sudo -u "$USER_NAME" tee "$RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json" > /dev/null <<EOF
{
    "pruning-enabled": false,
    "state-sync-enabled": true,
    "eth-apis": [
        $ethAPIs
    ]
}
EOF

# create the C-Chain config:
echo "Creating C-chain config file $RIZENET_DATA_DIR/configs/chains/C/config.json"
sudo -u "$USER_NAME" tee "$RIZENET_DATA_DIR/configs/chains/C/config.json" > /dev/null <<EOF
{
  "pruning-enabled": true,
  "eth-apis": [
    $ethAPIs
  ]
}
EOF



# reload settings, enable and start the service:
echo "Launching node"
sleep 1;
sudo systemctl daemon-reload
sleep 1;
sudo systemctl enable avalanchego
sleep 1;
sudo systemctl restart avalanchego

sleep 5

# show if it is running correctly:
sudo systemctl status avalanchego --no-pager

echo
echo
echo

echo "The node is initialize and currently bootstrapping (syncing with the rest of the network)."
echo
echo


# Wait until the node has finished bootstrapping
while true; do
  BOOTSTRAP_STATUS=$(curl -s -X POST --data '{"jsonrpc":"2.0", "id":1, "method":"info.isBootstrapped", "params":{"chain":"X"}}' \
    -H 'content-type:application/json;' 127.0.0.1:${RPC_PORT}/ext/info | jq -r '.result.isBootstrapped')
  if [ "$BOOTSTRAP_STATUS" = "true" ]; then
    echo "Chain bootstrapping is done!"
    break
  fi

  seconds_to_wait=120

  echo "Chain is bootstrapping. Waiting $seconds_to_wait seconds and checking again."
  sleep $seconds_to_wait

done

echo
echo
echo
echo
echo "Chain is bootstrapped!"


# reload settings, enable and start the service:
echo "Restarting node service..."
sleep 2
sudo systemctl restart avalanchego
# show if it is running correctly:
sleep 5;
sudo systemctl status avalanchego --no-pager
echo
echo



echo
echo
echo
echo "Joining ${CHAIN_NAME}"

echo "Importing dat file from $REPOSITORY_PATH/$CHAIN_NAME.dat"
sudo -u "$USER_NAME" bash -c "
  export PATH=$USER_HOME/bin:\$PATH
  avalanche blockchain import file '$REPOSITORY_PATH/$CHAIN_NAME.dat' --force
"

# list all available subnets on this server
echo "Done. Ready to join the subnet:"
sudo -u "$USER_NAME" bash -c "
  export PATH=$USER_HOME/bin:\$PATH
  avalanche blockchain list
"


echo
echo "Joining ${CHAIN_NAME}"
sudo -u "$USER_NAME" bash -c "
  export PATH=$USER_HOME/bin:\$PATH
  avalanche blockchain join '${CHAIN_NAME}' \
    --data-dir '$RIZENET_DATA_DIR' \
    $AVALANCHE_NETWORK_FLAG \
    --avalanchego-config '$RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json' \
    --force-write --plugin-dir '$RIZENET_DATA_DIR/plugins'
"

echo
echo "Success! Restarting the node service..."
sleep 2;
sudo systemctl restart avalanchego
# show if it is running correctly:
sleep 5;
sudo systemctl status avalanchego --no-pager


printf '\n%.0s' {1..6}


# execute migrations to bring node to the latest version:
echo "Executing migrations to bring node to the latest version:"
source "$SCRIPT_DIR/executeMigrations.sh"

# printf '\n%.0s' {1..15}

# echo "Your node is ready to join the ${CHAIN_NAME} as a validator!"
# echo
# echo "Please send the data below to your ${CHAIN_NAME} Admin contact so they can take care of staking to your node and sending the required transaction to the network."
# echo
# NODE_ID=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' -H 'content-type:application/json;' 127.0.0.1:${RPC_PORT}/ext/info | jq -r '.result.nodeID')
# echo "Node ID: $NODE_ID"
# echo "Node BLS Public Key (nodePOP.publicKey): '`curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' -H 'content-type:application/json;' 127.0.0.1:${RPC_PORT}/ext/info | jq -r '.result.nodePOP.publicKey'`'"
# echo "Node BLS Signature (proofOfPossession): '`curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' -H 'content-type:application/json;' 127.0.0.1:${RPC_PORT}/ext/info | jq -r '.result.nodePOP.proofOfPossession'`'"
# echo

printf '\n%.0s' {1..30}

# generate a random encryption and decryption passphrase
passphrase=$(openssl rand -base64 16)

# encrypt the transaction file so we can safely upload it to free file sharing services:
encrypted_data=$(encrypt_and_output $HOME/rizenet_node_deployment.log $passphrase)
# Upload the encrypted data
export datetime=$(date +%Y-%m-%d-%H-%M)
upload_encrypted_data "$encrypted_data" "rizenet_node_deployment-$NODE_ID-$datetime.log" "$HOME/rizenet_node_deployment.log" "$passphrase"

echo
echo "Node deployed. Congratulations!"
echo

# print DEPOYMENT_FINISHED which will trigger the tail program to exit graceously
echo "DEPOYMENT_FINISHED"
echo
