#!/bin/bash

# Source the myNodeConfig.sh file from the same directory
export SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")

# verify and load the config:
echo "Executing checkNodeConfig.sh"
source "$SCRIPT_DIR/checkNodeConfig.sh"

# Current migration version, which facilitates node upgrades:
export MIGRATION_ID="2"


# Check if the script is being run with sudo by a normal user
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ] || [ "$SUDO_USER" = "root" ]; then
  echo "This script must be run with sudo by a normal user, not directly as root or without sudo." >&2
  exit 1
fi

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
  # Install unattended-upgrades
  sudo apt install unattended-upgrades -y

  # Enable automatic updates via dpkg-reconfigure
  sudo dpkg-reconfigure -fnoninteractive --priority=low unattended-upgrades

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


# Install dependencies:
echo "Installing dependencies"
sudo apt update
sudo apt upgrade -y
sudo apt install -y gcc jq openssl curl


# go must be installed manually on ubuntu because the old version is on the repo
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

# Create the migration, which tracks the current version of the node and facilitates upgrades
MIGRATION_FILE="$SCRIPT_DIR/migration"
if [ ! -f "$MIGRATION_FILE" ]; then
  echo "$MIGRATION_ID" > "$MIGRATION_FILE"
fi

echo "Creating avalanchego node configuration file"
sudo -u "$USER_NAME" mkdir -p "$RIZENET_DATA_DIR/configs/avalanchego"


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
ethAPIs='
  "eth",
  "eth-filter",
  "net",
  "web3",
  "internal-eth",
  "internal-blockchain",
  "internal-transaction",
  "debug-tracer",
  "internal-tx-pool"
'


# create the subnet config:
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
sudo -u "$USER_NAME" tee "$RIZENET_DATA_DIR/configs/chains/C/config.json" > /dev/null <<EOF
{
    "pruning-enabled": false,
    "state-sync-enabled": true,
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

  seconds_to_wait=60

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


echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo
echo "Your node is ready to join the ${CHAIN_NAME} as a validator!"
echo
echo "Please send the data below to your ${CHAIN_NAME} Admin contact so they can take care of staking to your node and sending the required transaction to the network."
echo "Alternatively, you can do it yourself, in which case please contact your ${CHAIN_NAME} Admin contact so they can sign your transaction."
echo
echo "Node ID: '`curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' -H 'content-type:application/json;' 127.0.0.1:${RPC_PORT}/ext/info | jq -r '.result.nodeID'`'"
echo "Node BLS Public Key (nodePOP.publicKey): '`curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' -H 'content-type:application/json;' 127.0.0.1:${RPC_PORT}/ext/info | jq -r '.result.nodePOP.publicKey'`'"
echo "Node BLS Signature (proofOfPossession): '`curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' -H 'content-type:application/json;' 127.0.0.1:${RPC_PORT}/ext/info | jq -r '.result.nodePOP.proofOfPossession'`'"
echo


