#!/bin/bash

# Get the rizenet-node directory to work with
export SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")

# verify and load the config:
echo "Executing checkNodeConfig.sh"
source "$SCRIPT_DIR/checkNodeConfig.sh"

# Load util functions (like upload_encrypted_data) to encrypt files and upload metadata
echo "Sourcing common functions from $SCRIPT_DIR/util.sh"
source "$SCRIPT_DIR/util.sh"


# Get the parameters
SOURCE_RIZENET_DATA_DIR="$1"      # First parameter: source
DESTINATION_RIZENET_DATA_DIR="$2" # Second parameter: destination

# constants:
export USER_NAME=${SUDO_USER:-$(whoami)}
export GROUP_NAME=$(id -gn ${SUDO_USER:-$(whoami)})

# Check if DESTINATION_RIZENET_DATA_DIR exists, exit if it doesn't
if [ ! -d "$DESTINATION_RIZENET_DATA_DIR" ]; then
  echo "Note: Destination $DESTINATION_RIZENET_DATA_DIR does not exist. Creating for USER_NAME:GROUP_NAME"

  # create empty dir
  sudo mkdir $DESTINATION_RIZENET_DATA_DIR
  # change ownership of the dir
  sudo chown -R $USER_NAME:$USER_NAME $DESTINATION_RIZENET_DATA_DIR
fi

# Check if SOURCE_RIZENET_DATA_DIR exists
if [ ! -d "$SOURCE_RIZENET_DATA_DIR" ]; then
  echo "Error: Source $SOURCE_RIZENET_DATA_DIR does not exist."
  prepare_audit_logs "rizenet_node_operations.log"
  exit 1
fi


# validate the avalanche go config
# Define the config file path
AVALANCHE_GO_CONFIG_FILE="$SOURCE_RIZENET_DATA_DIR/configs/avalanchego/config.json"

# Check if config file exists
if [ ! -f "$AVALANCHE_GO_CONFIG_FILE" ]; then
  echo "Error: Avalanche Go config file not found at $AVALANCHE_GO_CONFIG_FILE"
  prepare_audit_logs "rizenet_node_operations.log"
  exit 1
fi

# Extract the current data-dir value from the file
current_value=$(grep '"data-dir":' "$AVALANCHE_GO_CONFIG_FILE" | sed 's/.*"data-dir": *"\([^"]*\)".*/\1/')
if [ -z "$current_value" ]; then
  echo "Error: data-dir variable not found in the avalanche go config file $AVALANCHE_GO_CONFIG_FILE."
  prepare_audit_logs "rizenet_node_operations.log"
  exit 1
fi
echo "Current data-dir value on $AVALANCHE_GO_CONFIG_FILE: $current_value"


# export the validated variables
export SOURCE_RIZENET_DATA_DIR
export DESTINATION_RIZENET_DATA_DIR


# Define the service file location
SERVICE_FILE="/etc/systemd/system/avalanchego.service"

# Check if the service file exists
if [ ! -f "$SERVICE_FILE" ]; then
  echo "Error: Service file not found at $SERVICE_FILE"
  prepare_audit_logs "rizenet_node_operations.log"
  exit 1
fi

# Extract current WorkingDirectory value in the service file
current_working_dir=$(grep '^WorkingDirectory=' "$SERVICE_FILE" | head -n1 | cut -d'=' -f2)
if [ -z "$current_working_dir" ]; then
  echo "Error: WorkingDirectory not found in $SERVICE_FILE."
  prepare_audit_logs "rizenet_node_operations.log"
  exit 1
fi
echo "Current WorkingDirectory on $SERVICE_FILE: $current_working_dir"

# Extract current ExecStart value in the service file
current_exec_start=$(grep '^ExecStart=' "$SERVICE_FILE" | head -n1 | cut -d'=' -f2-)
if [ -z "$current_exec_start" ]; then
  echo "Error: ExecStart not found in $SERVICE_FILE."
  prepare_audit_logs "rizenet_node_operations.log"
  exit 1
fi
echo "Current ExecStart on $SERVICE_FILE: $current_exec_start"



# backup the node staker files, used to identify the node on the network and to
# recreate the node in case of disaster. They must be kep private and safe
export datetime=$(date +%Y-%m-%d-%H-%M)
sudo -u "$USER_NAME" bash -c "
  cp $RIZENET_DATA_DIR/staking/staker.crt $BACKUPS_FOLDER/backup_of_staker.crt.before_mvDataDir_at_migration_$MIGRATION_ID-${datetime}
  cp $RIZENET_DATA_DIR/staking/staker.key $BACKUPS_FOLDER/backup_of_staker.key.before_mvDataDir_at_migration_$MIGRATION_ID-${datetime}

  cp config.sh "$BACKUPS_FOLDER/nodeConfigBackup-at_migration_$MIGRATION_ID-${datetime}.sh"
  cp myNodeConfig.sh "$BACKUPS_FOLDER/myNodeConfigBackup-at_migration_$MIGRATION_ID-${datetime}.sh"
"



# We are ready to move. Start by stopping the node:
sudo systemctl stop avalanchego



# update the value in the service file:
# Define new values using DESTINATION_RIZENET_DATA_DIR
new_working_dir="$DESTINATION_RIZENET_DATA_DIR"
new_exec_start="$DESTINATION_RIZENET_DATA_DIR/avalanchego/build/avalanchego --config-file \"$DESTINATION_RIZENET_DATA_DIR/configs/avalanchego/config.json\""

# Update WorkingDirectory in the service file
sudo sed -i 's|^WorkingDirectory=.*|WorkingDirectory='"$new_working_dir"'|' "$SERVICE_FILE"

# Update ExecStart in the service file
sudo sed -i 's|^ExecStart=.*|ExecStart='"$new_exec_start"'|' "$SERVICE_FILE"

# Verify the update for WorkingDirectory
updated_working_dir=$(grep '^WorkingDirectory=' "$SERVICE_FILE" | head -n1 | cut -d'=' -f2)
if [ "$updated_working_dir" != "$new_working_dir" ]; then
  echo "Error: Failed to update WorkingDirectory in $SERVICE_FILE."
  prepare_audit_logs "rizenet_node_operations.log"
  exit 1
else
  echo "Success: WorkingDirectory in $SERVICE_FILE updated to $updated_working_dir"
fi

# Verify the update for ExecStart
updated_exec_start=$(grep '^ExecStart=' "$SERVICE_FILE" | head -n1 | cut -d'=' -f2-)
if [ "$updated_exec_start" != "$new_exec_start" ]; then
  echo "Error: Failed to update ExecStart in $SERVICE_FILE."
  prepare_audit_logs "rizenet_node_operations.log"
  exit 1
else
  echo "Success: ExecStart in $SERVICE_FILE updated to $updated_exec_start"
fi

# reload services daemon since we touched the service file:
sudo systemctl daemon-reload



# also edit the avalanche go config file:
# Update the data-dir value in the config file
sed -i.bak "s#\"data-dir\": *\"[^\"]*\"#\"data-dir\": \"$DESTINATION_RIZENET_DATA_DIR\"#" "$AVALANCHE_GO_CONFIG_FILE"

# Verify the update by re-extracting the value
updated_value=$(grep '"data-dir":' "$AVALANCHE_GO_CONFIG_FILE" | sed 's/.*"data-dir": *"\([^"]*\)".*/\1/')

if [ "$updated_value" == "$DESTINATION_RIZENET_DATA_DIR" ]; then
  echo "Success: data-dir updated to $updated_value in $AVALANCHE_GO_CONFIG_FILE"
else
  echo "Error: Failed to update data-dir on $AVALANCHE_GO_CONFIG_FILE."
  sudo systemctl restart avalanchego
  prepare_audit_logs "rizenet_node_operations.log"
  exit 1
fi



# Finally, do the actual moving of the data dir folder and files then show the result:
echo "Moving the data directory from $SOURCE_RIZENET_DATA_DIR to $DESTINATION_RIZENET_DATA_DIR."
echo "This operation can take anywhere from an instant to many minutes, depending on the speed of the drives involved."
mv -T $SOURCE_RIZENET_DATA_DIR $DESTINATION_RIZENET_DATA_DIR
echo "Data dir moved into $DESTINATION_RIZENET_DATA_DIR:"
ls -lah $DESTINATION_RIZENET_DATA_DIR



# update the value in the config of the node:
sed -i "s|^export RIZENET_DATA_DIR=.*|export RIZENET_DATA_DIR=\"$DESTINATION_RIZENET_DATA_DIR\"|" "./myNodeConfig.sh"



# finish by restarting the node
echo "Restarting node..."
sudo systemctl restart avalanchego


# wait a bit for node to restart
sleep 20

# show if it is running correctly:
echo "printing status of avalanchego service:"
sudo systemctl status avalanchego --no-pager



# prepare logs to be audited by a Rizenet Admin:
prepare_audit_logs "rizenet_node_operations.log"

echo
# print OPERATION_FINISHED which will trigger the tail program to exit graceously
echo "OPERATION_FINISHED"
echo
