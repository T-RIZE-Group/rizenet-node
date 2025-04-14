#!/bin/bash

export datetime=$(date +%Y-%m-%d-%H-%M)
LOG_FILE_NAME="rizenet_node-$NODE_ID-$datetime.log"
LOG_FILE_PATH="/tmp/shareLogs-$LOG_FILE_NAME"



# Get the rizenet-node directory to work with
export SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")
printf "SCRIPT_DIR: $SCRIPT_DIR" >> $LOG_FILE_PATH

# Load util functions (like upload_encrypted_data) to encrypt files and upload metadata
printf "\n\n" >> $LOG_FILE_PATH
printf "Sourcing common functions from $SCRIPT_DIR/util.sh" >> $LOG_FILE_PATH
source "$SCRIPT_DIR/util.sh" >> $LOG_FILE_PATH 2>&1



# execute an internet speed test with speedtest.net
# Check if the speedtest command exists; if not, install it.
if ! command -v speedtest >/dev/null 2>&1; then
  echo "speedtest not found; attempting installation..." >> "$LOG_FILE_PATH" 2>&1
  if command -v apt-get >/dev/null 2>&1; then
    echo "Installing for Debian/Ubuntu systems" >> "$LOG_FILE_PATH" 2>&1
    sudo apt-get install -y curl >> "$LOG_FILE_PATH" 2>&1
    # Install the repository via the script
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash >> "$LOG_FILE_PATH" 2>&1

    # Replace the distribution field (the first token after the URL) with "jammy".
    # this fixes the package not being available on all versions of ubuntu.
    sudo sed -i -E 's|(ubuntu/)[[:space:]]*[^[:space:]]+|\1 jammy|' /etc/apt/sources.list.d/ookla_speedtest-cli.list >> "$LOG_FILE_PATH" 2>&1

    sudo apt-get update >> "$LOG_FILE_PATH" 2>&1
    sudo apt-get install -y speedtest >> "$LOG_FILE_PATH" 2>&1
  elif command -v yum >/dev/null 2>&1; then
    echo "Installing for Fedora/RHEL/CentOS systems" >> "$LOG_FILE_PATH" 2>&1
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash >> "$LOG_FILE_PATH" 2>&1
    sudo yum install -y speedtest >> "$LOG_FILE_PATH" 2>&1
  else
    echo "No supported package manager found. Please install speedtest manually." >> "$LOG_FILE_PATH" 2>&1
  fi
fi

# Check if installation succeeded and run speedtest if available
if command -v speedtest >/dev/null 2>&1; then
  printf "\n\n" >> "$LOG_FILE_PATH" 2>&1
  printf "Running speedtest:" >> "$LOG_FILE_PATH" 2>&1
  speedtest --format=human-readable --progress=no --accept-license -u MB/s >> "$LOG_FILE_PATH" 2>&1
else
  printf "\n\n" >> "$LOG_FILE_PATH" 2>&1
  printf "Failed to run speedtest" >> "$LOG_FILE_PATH" 2>&1
fi




# Print current datetime
printf "\n\n" >> $LOG_FILE_PATH
printf "Current DateTime: $datetime\n" >> $LOG_FILE_PATH 2>&1

# Print current Linux version, distro, and kernel version
printf "Linux Version: $(uname -v)\n" >> $LOG_FILE_PATH 2>&1
printf "Distro:\n$(lsb_release -a 2>/dev/null)\n" >> $LOG_FILE_PATH 2>&1
printf "Kernel Version: $(uname -r)\n" >> $LOG_FILE_PATH 2>&1

# Print Go version
printf "\n\n" >> $LOG_FILE_PATH
printf "Go version: $(go version)" >> $LOG_FILE_PATH 2>&1

# Print disk usage
printf "\n\n" >> $LOG_FILE_PATH
printf "Disk Usage:\n" >> $LOG_FILE_PATH 2>&1
df -h >> $LOG_FILE_PATH 2>&1

# Query external IP from 3 different servers with a 10 second timeout
printf "\n\n" >> $LOG_FILE_PATH
printf "External IP:\n" >> $LOG_FILE_PATH 2>&1

# Array of IP-check services
SERVERS=(
    "ifconfig.co"
    "https://myipv4.p1.opendns.com/get_my_ip"
    "ifconfig.me"
    "https://myip.dnsomatic.com/"
    "https://api.ipify.org/"
    "my.ip.fi"
    "https://ipprintf.net/plain"
)

# Loop through each service and log the result
for server in "${SERVERS[@]}"; do
    # Redirect stderr inside the command substitution
    ip=$(curl --max-time 10 -s "$server" 2>&1)
    if [ -n "$ip" ]; then
        printf "%s - according to %s\n" "$ip" "$server" >> "$LOG_FILE_PATH" 2>&1
    else
        printf "Failed to fetch IP (timeout or no response) from %s\n" "$server" >> "$LOG_FILE_PATH" 2>&1
    fi
done


# Function to print all variables and their values from the config file
print_config_vars() {
  # Source the config file
  source "$SCRIPT_DIR/myNodeConfig.sh"

  # Read and print each line of the config file
  while IFS= read -r line; do
    # Ignore empty lines or comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Print each line (which should be in the form of 'export VAR=value')
    printf "$line\n"
  done < "$SCRIPT_DIR/myNodeConfig.sh"
}


printf "Plugins / VM folder $RIZENET_DATA_DIR/plugins/:\n"
ls -lah $RIZENET_DATA_DIR/plugins

printf "Backups folder $BACKUPS_FOLDER:\n"
ls -lah $BACKUPS_FOLDER

printf "Avalanchego node configuration file $RIZENET_DATA_DIR/configs/avalanchego/config.json:\n"
cat $RIZENET_DATA_DIR/configs/avalanchego/config.json
ls -lah $RIZENET_DATA_DIR/configs/avalanchego/config.json

printf "Avalanchego service file /etc/systemd/system/avalanchego.service:\n"
cat /etc/systemd/system/avalanchego.service
ls -lah /etc/systemd/system/avalanchego.service

printf "Rizenet Blockchain config file $RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json:\n"
cat $RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json
ls -lah $RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json

printf "C-Chain Blockchain config file $RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json:\n"
cat $RIZENET_DATA_DIR/configs/chains/C/config.json
ls -lah $RIZENET_DATA_DIR/configs/chains/C/config.json

printf "PATH system variable:\n"
echo $PATH


printf "\n\n" >> $LOG_FILE_PATH
printf "Node config:\n\n" >> $LOG_FILE_PATH
print_config_vars >> $LOG_FILE_PATH


printf "\n\n" >> $LOG_FILE_PATH
printf "Current migration ID:" >> $LOG_FILE_PATH
cat "$SCRIPT_DIR/migration" >> $LOG_FILE_PATH 2>&1


printf "\n\n" >> $LOG_FILE_PATH
printf "Status of avalanchego:\n" >> $LOG_FILE_PATH
systemctl status avalanchego --no-pager >> $LOG_FILE_PATH 2>&1


printf "\n\n" >> $LOG_FILE_PATH
printf "Status of prometheus:\n" >> $LOG_FILE_PATH
systemctl status prometheus --no-pager >> $LOG_FILE_PATH 2>&1


printf "\n\n" >> $LOG_FILE_PATH
printf "Status of node_exporter:\n" >> $LOG_FILE_PATH
systemctl status node_exporter --no-pager >> $LOG_FILE_PATH 2>&1


printf "\n\n" >> $LOG_FILE_PATH
printf "health.health for the subnet $SUBNET_ID:\n" >> $LOG_FILE_PATH
curl -H "Content-Type: application/json" --data "{
    \"jsonrpc\": \"2.0\",
    \"id\": 1,
    \"method\": \"health.health\",
    \"params\": {
        \"tags\": [\"$SUBNET_ID\"]
    }
}" "http://127.0.0.1:$RPC_PORT/ext/health" >> $LOG_FILE_PATH 2>&1

printf "\n\n" >> $LOG_FILE_PATH
printf "info.getNodeVersion:\n" >> $LOG_FILE_PATH
curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"id\": 1,
    \"method\": \"info.getNodeVersion\"
}" -H "content-type:application/json;" "127.0.0.1:$RPC_PORT/ext/info" >> $LOG_FILE_PATH 2>&1

printf "\n\n" >> $LOG_FILE_PATH
printf "platform.getBlockchainStatus:\n" >> $LOG_FILE_PATH
curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"platform.getBlockchainStatus\",
    \"params\": {
        \"blockchainID\": \"$CHAIN_ID\"
    },
    \"id\": 1
}" -H "content-type:application/json;" "http://127.0.0.1:$RPC_PORT/ext/bc/P" >> $LOG_FILE_PATH 2>&1

printf "\n\n" >> $LOG_FILE_PATH
printf "info.isBootstrapped:\n" >> $LOG_FILE_PATH
curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"id\": 1,
    \"method\": \"info.isBootstrapped\",
    \"params\": {\"chain\": \"X\"}
}" -H "content-type:application/json;" "127.0.0.1:$RPC_PORT/ext/info" >> $LOG_FILE_PATH 2>&1

printf "\n\n" >> $LOG_FILE_PATH
printf "platform.getCurrentValidators:\n" >> $LOG_FILE_PATH
curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"platform.getCurrentValidators\",
    \"params\": {
        \"subnetID\": \"$SUBNET_ID\"
    },
    \"id\": 1
}" -H "content-type:application/json;" "http://127.0.0.1:$RPC_PORT/ext/bc/P" >> $LOG_FILE_PATH 2>&1




printf "\n\n" >> $LOG_FILE_PATH
printf "Logs of avalanchego:\n" >> $LOG_FILE_PATH
journalctl -u avalanchego >> $LOG_FILE_PATH 2>&1


# generate a random encryption and decryption passphrase
passphrase=$(openssl rand -base64 16)

# encrypt the transaction file so we can safely upload it to free file sharing services:
encrypted_data=$(encrypt_and_output $LOG_FILE_PATH $passphrase)

# Upload the encrypted data and print the output on the screen
upload_encrypted_data "$encrypted_data" "$LOG_FILE_NAME" "$LOG_FILE_PATH" "$passphrase"

# the script will have created two exact files. Lets delete one of them:
rm $LOG_FILE_PATH

echo ";)"
