#!/bin/bash

# Get the rizenet-node directory to work with
export SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")

# Check if the script is being run with sudo by a normal user
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ] || [ "$SUDO_USER" = "root" ]; then
  echo "This script must be run with sudo by a normal user, not directly as root or without sudo." >&2
  exit 1
fi

# verify and load the config:
echo "Executing checkNodeConfig.sh"
source "$SCRIPT_DIR/checkNodeConfig.sh"

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


if [ "$MIGRATION_ID" -eq 0 ]; then
  echo -e "Running migration to update node from migration $MIGRATION_ID to migration 1...\n"
  source "$SCRIPT_DIR/migration001.sh"
  export MIGRATION_ID=1
  sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE"
  printf "\n\nDone executing migration $MIGRATION_ID on your Rizenet node!\n\n"
fi

if [ "$MIGRATION_ID" -eq 1 ]; then
  echo -e "Running migration to update node from migration $MIGRATION_ID to migration 2...\n"
  source "$SCRIPT_DIR/migration002.sh"
  export MIGRATION_ID=2
  sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE"
  printf "\n\nDone executing migration $MIGRATION_ID on your Rizenet node!\n\n"
fi

if [ "$MIGRATION_ID" -eq 2 ]; then
  echo -e "Running migration to update node from migration $MIGRATION_ID to migration 3...\n"
  source "$SCRIPT_DIR/migration003.sh"
  export MIGRATION_ID=3
  sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE"
  printf "\n\nDone executing migration $MIGRATION_ID on your Rizenet node!\n\n"
fi


if [ "$MIGRATION_ID" -eq 3 ]; then
  echo -e "Running migration to update node from migration $MIGRATION_ID to migration 4...\n"
  source "$SCRIPT_DIR/migration004.sh"
  export MIGRATION_ID=4
  sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE"
  printf "\n\nDone executing migration $MIGRATION_ID on your Rizenet node!\n\n"
fi

if [ "$MIGRATION_ID" -eq 4 ]; then
  echo -e "Running migration to update node from migration $MIGRATION_ID to migration 5...\n"
  source "$SCRIPT_DIR/migration005.sh"
  export MIGRATION_ID=5
  sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE"
  printf "\n\nDone executing migration $MIGRATION_ID on your Rizenet node!\n\n"
fi

if [ "$MIGRATION_ID" -eq 5 ]; then
  echo -e "Running migration to update node from migration $MIGRATION_ID to migration 5...\n"
  source "$SCRIPT_DIR/migration006.sh"
  export MIGRATION_ID=6
  sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE"
  printf "\n\nDone executing migration $MIGRATION_ID on your Rizenet node!\n\n"
fi

# for the future:
# if [ "$MIGRATION_ID" -eq 6 ]; then
#   echo -e "Running migration to update node from migration $MIGRATION_ID to migration 6...\n"
#   source "$SCRIPT_DIR/migration007.sh"
#   export MIGRATION_ID=7
#   sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE"
#   printf "\n\nDone executing migration $MIGRATION_ID on your Rizenet node!\n\n"
# fi



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
