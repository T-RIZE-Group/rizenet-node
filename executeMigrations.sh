#!/bin/bash

# Check if the script is being run with sudo by a normal user
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ] || [ "$SUDO_USER" = "root" ]; then
  echo "This script must be run with sudo by a normal user, not directly as root or without sudo." >&2
  exit 1
fi

# Get the rizenet-node directory to work with
export SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")

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

# Create the file if it does not exist:
MIGRATION_FILE="$SCRIPT_DIR/migration"
if [ ! -f "$MIGRATION_FILE" ]; then
  sudo -u "$USER_NAME" bash -c "
    echo '0' > '$MIGRATION_FILE'
  "
fi

export MIGRATION_ID=$(head -n 1 "$MIGRATION_FILE")
echo -e "Current MIGRATION_ID = $MIGRATION_ID"

# create a folder for backups if it does not exist:
sudo -u "$USER_NAME" bash -c "
  mkdir -p $BACKUPS_FOLDER
"

# backup the node staker files, used to identify the node on the network and to
# recreate the node in case of disaster. They must be kep private and safe
export datetime=$(date +%Y-%m-%d-%H-%M)
sudo -u "$USER_NAME" bash -c "
  cp $RIZENET_DATA_DIR/staking/staker.crt $BACKUPS_FOLDER/backup_of_staker.crt.at_migration_$MIGRATION_ID-${datetime}
  cp $RIZENET_DATA_DIR/staking/staker.key $BACKUPS_FOLDER/backup_of_staker.key.at_migration_$MIGRATION_ID-${datetime}

  cp config.sh "$BACKUPS_FOLDER/nodeConfigBackup-at_migration_$MIGRATION_ID-${datetime}.sh"
  cp myNodeConfig.sh "$BACKUPS_FOLDER/myNodeConfigBackup-at_migration_$MIGRATION_ID-${datetime}.sh"
"

# ensure MIGRATION_ID is set and numeric
[[ $MIGRATION_ID =~ ^[0-9]+$ ]] || { echo "MIGRATION_ID must be a number"; exit 1; }

# compute next id and script path (e.g., migration001.sh, migration006.sh, etc.)
next=$((MIGRATION_ID + 1))
next_pad=$(printf "%03d" "$next")
script="$SCRIPT_DIR/migration${next_pad}.sh"

# only run if the expected script exists (mirrors the original per-ID guards)
if [ -f "$script" ]; then
  echo -e "Running migration to update node from migration $MIGRATION_ID to migration $next...\n"
  source "$script"                                # run the specific migration
  export MIGRATION_ID=$next                       # bump the exported ID
  sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE" # persist to file (first line)
  printf "\n\nDone executing migration $MIGRATION_ID on your Rizenet node!\n\n"
fi


# generate a random encryption and decryption passphrase
passphrase=$(openssl rand -base64 16)

# encrypt the transaction file so we can safely upload it to free file sharing services:
encrypted_data=$(encrypt_and_output $HOME/rizenet_node_migrations.log $passphrase)
# Upload the encrypted data
export datetime=$(date +%Y-%m-%d-%H-%M)
upload_encrypted_data "$encrypted_data" "rizenet_node_migrations-$NODE_ID-$datetime.log" "$HOME/rizenet_node_migrations.log" "$passphrase"


echo
# print MIGRATIONS_FINISHED which will trigger the tail program to exit graceously
echo "MIGRATIONS_FINISHED"
echo
