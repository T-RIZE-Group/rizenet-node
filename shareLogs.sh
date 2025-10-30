#!/bin/bash


# This script collects data that can be used for investigating issues with a node and makes it easily
# shareable with others through an encrypted file that is uploaded to the cloud.
# Once it is finished it will give you the output that can be shared with others. It looks like:
# Done!
#
# curl -o /tmp/encrypted_rizenet_node--2025-04-26-16-07.log https://files.catbox.moe/2h2mxa && gpg --decrypt --batch --pinentry-mode loopback --passphrase NBmPtd0oiErQfxeoy++cSQ== -o /tmp/decrypted_rizenet_node--2025-04-26-16-07.log /tmp/encrypted_rizenet_node--2025-04-26-16-07.log
#
# Please share the command above with Rizenet Admin contact, so they can make sure everything went well with the execution of this operation!





# Check if the script is being run with sudo by a normal user
if [ "$EUID" -eq 0 ] || [ -n "$SUDO_USER" ]; then
  echo "This script must be run without sudo by a normal user, not directly as root or with sudo."
  exit 1
fi

# ask for sudo password only once, if needed:
if sudo -l -n 2>/dev/null | grep -q "NOPASSWD:"; then
  echo "Sudo is passwordless; skipping sudo password request."
else
  echo "Sudo requires a password; running sudo -v to ask for sudo password:"
  sudo -v || { echo "Incorrect password or sudo not enabled. Exiting."; exit 1; }
fi


echo "Collecting data! This should take less than 10 minutes..."


# Get the rizenet-node directory to work with
export SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")

export datetime=$(date +%Y-%m-%d-%H-%M)
LOG_FILE_NAME="rizenet_node-$NODE_ID-$datetime.log"
LOG_FILE_PATH="/tmp/shareLogs-$LOG_FILE_NAME"
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "SCRIPT_DIR: $SCRIPT_DIR\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Working with SCRIPT_DIR: $SCRIPT_DIR \n" 2>&1 | tee -a "$LOG_FILE_PATH"


# Source the config file
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Making $SCRIPT_DIR/myNodeConfig.sh executable..." 2>&1 | tee -a "$LOG_FILE_PATH"
chmod +x $SCRIPT_DIR/myNodeConfig.sh 2>&1 | tee -a "$LOG_FILE_PATH"
printf "\nSourcing node config from $SCRIPT_DIR/myNodeConfig.sh - sourcing twice, one for logs and another for execution environment...\n" 2>&1 | tee -a "$LOG_FILE_PATH"
source "$SCRIPT_DIR/myNodeConfig.sh" 2>&1 | tee -a "$LOG_FILE_PATH"
source "$SCRIPT_DIR/myNodeConfig.sh"


# verify the config file by running the script checkNodeConfig.sh:
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Running script $SCRIPT_DIR/checkNodeConfig.sh - sourcing twice, one for logs and another for execution environment...\n" 2>&1 | tee -a "$LOG_FILE_PATH"
source "$SCRIPT_DIR/checkNodeConfig.sh" 2>&1 | tee -a "$LOG_FILE_PATH"
source "$SCRIPT_DIR/checkNodeConfig.sh"
# Check the return status of checkNodeConfig.sh and exit if it failed
if [ $? -eq 1 ]; then
  printf "\n\nNode config check failed!" 2>&1 | tee -a "$LOG_FILE_PATH"
else
  printf "\n\nNode config check successful!" 2>&1 | tee -a "$LOG_FILE_PATH"
fi


# Load util functions (like upload_encrypted_data) to encrypt files and upload metadata
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Sourcing common functions from $SCRIPT_DIR/util.sh - sourcing twice, one for logs and another for execution environment...\n" 2>&1 | tee -a "$LOG_FILE_PATH"
source "$SCRIPT_DIR/util.sh" 2>&1 | tee -a "$LOG_FILE_PATH"
source "$SCRIPT_DIR/util.sh"



# execute an internet speed test with speedtest.net
# Check if the speedtest command exists; if not, install it.
if ! command -v speedtest >/dev/null 2>&1; then
  echo "speedtest not found; attempting installation..." 2>&1 | tee -a "$LOG_FILE_PATH"
  if command -v apt-get >/dev/null 2>&1; then
    echo "Installing for Debian/Ubuntu systems" 2>&1 | tee -a "$LOG_FILE_PATH"
    sudo apt-get install -y curl 2>&1 | tee -a "$LOG_FILE_PATH"
    # Install the repository via the script
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash 2>&1 | tee -a "$LOG_FILE_PATH"

    # Replace the distribution field (the first token after the URL) with "jammy".
    # this fixes the package not being available on all versions of ubuntu.
    sudo sed -i -E 's|(ubuntu/)[[:space:]]*[^[:space:]]+|\1 jammy|' /etc/apt/sources.list.d/ookla_speedtest-cli.list 2>&1 | tee -a "$LOG_FILE_PATH"

    sudo apt-get update 2>&1 | tee -a "$LOG_FILE_PATH"
    sudo apt-get install -y speedtest 2>&1 | tee -a "$LOG_FILE_PATH"
  elif command -v yum >/dev/null 2>&1; then
    echo "Installing for Fedora/RHEL/CentOS systems" 2>&1 | tee -a "$LOG_FILE_PATH"
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash 2>&1 | tee -a "$LOG_FILE_PATH"
    sudo yum install -y speedtest 2>&1 | tee -a "$LOG_FILE_PATH"
  else
    echo "No supported package manager found. Please install speedtest manually." 2>&1 | tee -a "$LOG_FILE_PATH"
  fi
fi

# Check if installation succeeded and run speedtest if available
if command -v speedtest >/dev/null 2>&1; then
  printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
  printf "Running speedtest:" 2>&1 | tee -a "$LOG_FILE_PATH"
  speedtest --format=human-readable --progress=no --accept-license -u MB/s 2>&1 | tee -a "$LOG_FILE_PATH"
else
  printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
  printf "Failed to run speedtest" 2>&1 | tee -a "$LOG_FILE_PATH"
fi




# Print current datetime
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Current DateTime: $datetime\n" 2>&1 | tee -a "$LOG_FILE_PATH"


# Print current Linux version, distro, and kernel version
printf "Linux Version: $(uname -v)\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Distro:\n$(lsb_release -a 2>/dev/null)\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Kernel Version: $(uname -r)\n" 2>&1 | tee -a "$LOG_FILE_PATH"


# Print Go version
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Go version: $(go version)" 2>&1 | tee -a "$LOG_FILE_PATH"


# Print disk usage
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Disk Usage:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
df -h 2>&1 | tee -a "$LOG_FILE_PATH"

# Print disk models
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Disk Models:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
lsblk -d -o NAME,MODEL 2>&1 | tee -a "$LOG_FILE_PATH"

# Check if the ifconfig command exists; if not, install net-tools
if ! command -v ifconfig >/dev/null 2>&1; then
  echo "ifconfig not found; attempting installation..." 2>&1 | tee -a "$LOG_FILE_PATH"
  if command -v apt-get >/dev/null 2>&1; then
    echo "Installing net-tools for Debian/Ubuntu systems" 2>&1 | tee -a "$LOG_FILE_PATH"
    sudo apt-get update 2>&1 | tee -a "$LOG_FILE_PATH"
    sudo apt-get install -y net-tools 2>&1 | tee -a "$LOG_FILE_PATH"
  elif command -v yum >/dev/null 2>&1; then
    echo "Installing net-tools for Fedora/RHEL/CentOS systems" 2>&1 | tee -a "$LOG_FILE_PATH"
    sudo yum install -y net-tools 2>&1 | tee -a "$LOG_FILE_PATH"
  else
    echo "No supported package manager found. Please install net-tools manually." 2>&1 | tee -a "$LOG_FILE_PATH"
  fi
fi


printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Internal IP:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
ifconfig 2>&1 | tee -a "$LOG_FILE_PATH"


# Query external IP from 3 different servers with a 10 second timeout
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "External IP:\n" 2>&1 | tee -a "$LOG_FILE_PATH"

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
        printf "%s - according to %s\n" "$ip" "$server" 2>&1 | tee -a "$LOG_FILE_PATH"
    else
        printf "Failed to fetch IP (timeout or no response) from %s\n" "$server" 2>&1 | tee -a "$LOG_FILE_PATH"
    fi
done

printf "\n\nPlugins (VM) folder $RIZENET_DATA_DIR/plugins:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
ls -lah $RIZENET_DATA_DIR/plugins 2>&1 | tee -a "$LOG_FILE_PATH"

printf "\n\nBackups folder $BACKUPS_FOLDER:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
ls -lah $BACKUPS_FOLDER 2>&1 | tee -a "$LOG_FILE_PATH"

printf "\n\nAvalanchego node configuration file $RIZENET_DATA_DIR/configs/avalanchego/config.json:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
cat $RIZENET_DATA_DIR/configs/avalanchego/config.json 2>&1 | tee -a "$LOG_FILE_PATH"
ls -lah $RIZENET_DATA_DIR/configs/avalanchego/config.json 2>&1 | tee -a "$LOG_FILE_PATH"

printf "\n\nAvalanchego service file /etc/systemd/system/avalanchego.service:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
cat /etc/systemd/system/avalanchego.service 2>&1 | tee -a "$LOG_FILE_PATH"
ls -lah /etc/systemd/system/avalanchego.service 2>&1 | tee -a "$LOG_FILE_PATH"

printf "\n\nRizenet Blockchain config file $RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
cat $RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json 2>&1 | tee -a "$LOG_FILE_PATH"
ls -lah $RIZENET_DATA_DIR/configs/chains/$CHAIN_ID/config.json 2>&1 | tee -a "$LOG_FILE_PATH"

printf "\n\nC-Chain Blockchain config file $RIZENET_DATA_DIR/configs/chains/C/config.json:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
cat $RIZENET_DATA_DIR/configs/chains/C/config.json 2>&1 | tee -a "$LOG_FILE_PATH"
ls -lah $RIZENET_DATA_DIR/configs/chains/C/config.json 2>&1 | tee -a "$LOG_FILE_PATH"

printf "\n\nPATH system variable:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
echo $PATH 2>&1 | tee -a "$LOG_FILE_PATH"


# Function to print all variables and their values from the config file
print_config_vars() {
  # Read and print each line of the config file
  while IFS= read -r line; do
    # Ignore empty lines or comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Print each line (which should be in the form of 'export VAR=value')
    printf "$line\n"
  done < "$SCRIPT_DIR/myNodeConfig.sh"
}

printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Node config:\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
print_config_vars 2>&1 | tee -a "$LOG_FILE_PATH"


printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Current migration ID:" 2>&1 | tee -a "$LOG_FILE_PATH"
cat "$SCRIPT_DIR/migration" 2>&1 | tee -a "$LOG_FILE_PATH"


printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Status of avalanchego:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
systemctl status avalanchego --no-pager 2>&1 | tee -a "$LOG_FILE_PATH"


printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Status of prometheus:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
systemctl status prometheus --no-pager 2>&1 | tee -a "$LOG_FILE_PATH"


printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Status of node_exporter:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
systemctl status node_exporter --no-pager 2>&1 | tee -a "$LOG_FILE_PATH"


printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "health.health for the subnet $SUBNET_ID:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
curl -H "Content-Type: application/json" --data "{
    \"jsonrpc\": \"2.0\",
    \"id\": 1,
    \"method\": \"health.health\",
    \"params\": {
        \"tags\": [\"$SUBNET_ID\"]
    }
}" "http://127.0.0.1:$RPC_PORT/ext/health" 2>&1 | tee -a "$LOG_FILE_PATH"

printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "info.getNodeVersion:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"id\": 1,
    \"method\": \"info.getNodeVersion\"
}" -H "content-type:application/json;" "127.0.0.1:$RPC_PORT/ext/info" 2>&1 | tee -a "$LOG_FILE_PATH"

printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "platform.getBlockchainStatus:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"platform.getBlockchainStatus\",
    \"params\": {
        \"blockchainID\": \"$CHAIN_ID\"
    },
    \"id\": 1
}" -H "content-type:application/json;" "http://127.0.0.1:$RPC_PORT/ext/bc/P" 2>&1 | tee -a "$LOG_FILE_PATH"

printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "info.isBootstrapped:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"id\": 1,
    \"method\": \"info.isBootstrapped\",
    \"params\": {\"chain\": \"X\"}
}" -H "content-type:application/json;" "127.0.0.1:$RPC_PORT/ext/info" 2>&1 | tee -a "$LOG_FILE_PATH"

printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "platform.getCurrentValidators:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"platform.getCurrentValidators\",
    \"params\": {
        \"subnetID\": \"$SUBNET_ID\"
    },
    \"id\": 1
}" -H "content-type:application/json;" "http://127.0.0.1:$RPC_PORT/ext/bc/P" 2>&1 | tee -a "$LOG_FILE_PATH"

# Disk read benchmarks
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Benchmarking Disks (Read Test):\n" 2>&1 | tee -a "$LOG_FILE_PATH"
# Loop over each disk device from lsblk
for disk in $(lsblk -d -n -o NAME); do
  printf "\nBenchmark for /dev/$disk:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
  sudo hdparm -t /dev/$disk 2>&1 | tee -a "$LOG_FILE_PATH"
done

# Benchmark write performance safely with a temporary file
printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Benchmarking Disks (Write Test) in a safe way:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
# Loop over each non-empty mount point (each mounted filesystem)
for mp in $(lsblk -o MOUNTPOINT -nr | grep -v "^$"); do
  tmp_file_small="$mp/tmp_dd_test_file"  # temporary file path
  printf "\nSmall file benchmark for mount point %s:\n" "$mp" 2>&1 | tee -a "$LOG_FILE_PATH"
  # Write 100MB to a temporary file; adjust count for shorter tests if needed
  sudo dd if=/dev/zero of="$tmp_file_small" bs=32K count=400 conv=fdatasync 2>&1 | tee -a "$LOG_FILE_PATH"
  sudo rm -f "$tmp_file_small" 2>&1 | tee -a "$LOG_FILE_PATH"  # remove the temporary file after testing

  tmp_file="$mp/tmp_dd_test_file"  # temporary file path
  printf "\nMedium file benchmark for mount point %s:\n" "$mp" 2>&1 | tee -a "$LOG_FILE_PATH"
  # Write 100MB to a temporary file; adjust count for shorter tests if needed
  sudo dd if=/dev/zero of="$tmp_file" bs=16M count=50 conv=fdatasync 2>&1 | tee -a "$LOG_FILE_PATH"
  sudo rm -f "$tmp_file" 2>&1 | tee -a "$LOG_FILE_PATH"  # remove the temporary file after testing

  tmp_file_big="$mp/tmp_dd_test_file"  # temporary file path
  printf "\nBig file benchmark for mount point %s:\n" "$mp" 2>&1 | tee -a "$LOG_FILE_PATH"
  # Write 100MB to a temporary file; adjust count for shorter tests if needed
  sudo dd if=/dev/zero of="$tmp_file_big" bs=600M count=1 conv=fdatasync 2>&1 | tee -a "$LOG_FILE_PATH"
  sudo rm -f "$tmp_file_big" 2>&1 | tee -a "$LOG_FILE_PATH"  # remove the temporary file after testing
done




printf "\n\n" 2>&1 | tee -a "$LOG_FILE_PATH"
printf "Logs of avalanchego:\n" 2>&1 | tee -a "$LOG_FILE_PATH"
journalctl -u avalanchego 2>&1 | tee -a "$LOG_FILE_PATH"


# generate a random encryption and decryption passphrase
passphrase=$(openssl rand -base64 16)

# encrypt the transaction file so we can safely upload it to free file sharing services:
encrypted_data=$(encrypt_and_output $LOG_FILE_PATH $passphrase)

# Upload the encrypted data and print the output on the screen
upload_encrypted_data "$encrypted_data" "$LOG_FILE_NAME" "$LOG_FILE_PATH" "$passphrase"

# the script will have created two exact files. Lets delete one of them:
rm $LOG_FILE_PATH

echo ";)"
