#!/bin/bash

export datetime=$(date +%Y-%m-%d-%H-%M)
LOG_FILE_NAME="rizenet_node-$NODE_ID-$datetime.log"
LOG_FILE_PATH="/tmp/shareLogs-$LOG_FILE_NAME"






# Get the rizenet-node directory to work with
export SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")

# verify and load the config:
echo "Executing checkNodeConfig.sh"
source "$SCRIPT_DIR/checkNodeConfig.sh"

# Load util functions (like upload_encrypted_data) to encrypt files and upload metadata
echo "Sourcing common functions from $SCRIPT_DIR/util.sh"
source "$SCRIPT_DIR/util.sh"


echo "\n\n"
echo "Current migration ID:"
cat "$SCRIPT_DIR/migration"


echo "\n\n"
echo "Status of avalanchego: \n\n"
systemctl status avalanchego --no-pager > $LOG_FILE_PATH


echo "\n\n"
echo "Status of prometheus: \n\n"
systemctl status prometheus --no-pager > $LOG_FILE_PATH


echo "\n\n"
echo "Status of prometheus: \n\n"
systemctl status prometheus --no-pager > $LOG_FILE_PATH


echo "\n\n"
echo "Status of prometheus: \n\n"
systemctl status prometheus --no-pager > $LOG_FILE_PATH


echo "\n\n"
echo "Status of node_exporter: \n\n"
systemctl status node_exporter --no-pager > $LOG_FILE_PATH


echo "\n\n"
echo "Logs of avalanchego: \n\n"
journalctl -u avalanchego > $LOG_FILE_PATH


printf '\n%.0s' {1..50}


# generate a random encryption and decryption passphrase
passphrase=$(openssl rand -base64 16)

# encrypt the transaction file so we can safely upload it to free file sharing services:
encrypted_data=$(encrypt_and_output $LOG_FILE_PATH $passphrase)

# Upload the encrypted data and print the output on the screen
upload_encrypted_data "$encrypted_data" "$LOG_FILE_NAME" "$LOG_FILE_PATH" "$passphrase"

# the script will have created two exact files. Lets delete one of them:
rm $LOG_FILE_PATH

echo ";)"
