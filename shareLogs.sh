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



# Function to print all variables and their values from the config file
print_config_vars() {
  # Source the config file
  source "$SCRIPT_DIR/myNodeConfig.sh"

  # Read and print each line of the config file
  while IFS= read -r line; do
    # Ignore empty lines or comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Print each line (which should be in the form of 'export VAR=value')
    printf "$line"
  done < "$SCRIPT_DIR/myNodeConfig.sh"
}



printf "\n\n" >> $LOG_FILE_PATH
printf "Node config:\n\n" >> $LOG_FILE_PATH
print_config_vars >> $LOG_FILE_PATH


printf "\n\n" >> $LOG_FILE_PATH
printf "Current migration ID:" >> $LOG_FILE_PATH
cat "$SCRIPT_DIR/migration" >> $LOG_FILE_PATH 2>&1


printf "\n\n" >> $LOG_FILE_PATH
printf "Status of avalanchego:" >> $LOG_FILE_PATH
systemctl status avalanchego --no-pager >> $LOG_FILE_PATH 2>&1


printf "\n\n" >> $LOG_FILE_PATH
printf "Status of prometheus:" >> $LOG_FILE_PATH
systemctl status prometheus --no-pager >> $LOG_FILE_PATH 2>&1


printf "\n\n" >> $LOG_FILE_PATH
printf "Status of node_exporter:" >> $LOG_FILE_PATH
systemctl status node_exporter --no-pager >> $LOG_FILE_PATH 2>&1


printf "\n\n" >> $LOG_FILE_PATH
printf "Logs of avalanchego:" >> $LOG_FILE_PATH
journalctl -u avalanchego >> $LOG_FILE_PATH 2>&1


printf '\n%.0s' {1..50} >> $LOG_FILE_PATH


# generate a random encryption and decryption passphrase
passphrase=$(openssl rand -base64 16)

# encrypt the transaction file so we can safely upload it to free file sharing services:
encrypted_data=$(encrypt_and_output $LOG_FILE_PATH $passphrase)

# Upload the encrypted data and print the output on the screen
upload_encrypted_data "$encrypted_data" "$LOG_FILE_NAME" "$LOG_FILE_PATH" "$passphrase" >> $LOG_FILE_PATH 2>&1

# the script will have created two exact files. Lets delete one of them:
rm $LOG_FILE_PATH

printf ";)"
