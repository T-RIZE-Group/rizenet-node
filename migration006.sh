#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh
# exactly as described in https://docs.rizenet.io/docs/rizenet/Rizenet%20Blockchain/validators/node_updating

# this migration edits the C-Chain config to reduce the disk space occupied by the Rizenet node data:
# enable prunning - https://build.avax.network/docs/nodes/chain-configs/c-chain#pruning-enabled
# allow missing tries, require by prunning - https://build.avax.network/docs/nodes/chain-configs/c-chain#allow-missing-tries
# enable offline prunning, run the node, then disable it, require by prunning - https://build.avax.network/docs/nodes/chain-configs/c-chain#offline-pruning-enabled
# disable state sync - https://build.avax.network/docs/nodes/chain-configs/c-chain#state-sync-enabled
# enable state sync resume skip - https://build.avax.network/docs/nodes/chain-configs/c-chain#state-sync-skip-resume


# Set the file path
C_CHAIN_CONFIG="$RIZENET_DATA_DIR/configs/chains/C/config.json"


# Function to check and set property in JSON with temporary file
set_property() {
  local property=$1
  local value=$2

  # Capture the original config file ownership and permissions
  local orig_owner
  local orig_group
  local orig_permissions
  orig_owner=$(stat -c '%U' "$C_CHAIN_CONFIG")
  orig_group=$(stat -c '%G' "$C_CHAIN_CONFIG")
  orig_permissions=$(stat -c '%a' "$C_CHAIN_CONFIG")

  # Check if the property exists and modify it, else add the property with the value
  if jq -e ".\"${property}\"" "$C_CHAIN_CONFIG" > /dev/null; then
    # Modify the property and save to a temporary file
    jq ".\"${property}\" = ${value}" "$C_CHAIN_CONFIG" > $C_CHAIN_CONFIG.tmp.json && mv $C_CHAIN_CONFIG.tmp.json "$C_CHAIN_CONFIG"
  else
    # Add the new property and save to a temporary file
    jq ". + {\"${property}\": ${value}}" "$C_CHAIN_CONFIG" > $C_CHAIN_CONFIG.tmp.json && mv $C_CHAIN_CONFIG.tmp.json "$C_CHAIN_CONFIG"
  fi

  # Restore the file ownership and permissions
  chown "$orig_owner:$orig_group" "$C_CHAIN_CONFIG"
  chmod "$orig_permissions" "$C_CHAIN_CONFIG"
}


echo "Disk usage:"
df -h
echo ""
echo "Rizenet Data Dir path:"
echo $RIZENET_DATA_DIR
echo ""


# Check if pruning-enabled is true
if jq -e '.["pruning-enabled"] == true' "$C_CHAIN_CONFIG" > /dev/null; then
  echo "Prunning of the C-Chain is already enabled!"
else
  # now we follow https://build.avax.network/docs/nodes/maintain/reduce-disk-usage#disk-space-considerations

  echo "Setting property \"pruning-enabled\" to true"
  set_property "pruning-enabled" true

  echo "Setting property \"allow-missing-tries\" to true"
  set_property "allow-missing-tries" true

  # This is meant to be run manually, so after running with this flag once,
  # it must be toggled back to false before running the node again.
  # Therefore, you should run with this flag set to true and then set it to false on the subsequent run.
  echo "Setting property \"offline-pruning-enabled\" to true"
  set_property "offline-pruning-enabled" true

  # This flag must be set when offline pruning is enabled and sets the directory that offline pruning
  # will use to write its bloom filter to disk. This directory should not be changed in between runs
  # until offline pruning has completed.
  # First, create a dir for the bloom filter while the process runs then set the path on the config:
  echo "Creating folder \"$RIZENET_DATA_DIR/offline-pruning-filter-data\""
  sudo -u "$USER_NAME" bash -c "
    mkdir -p $RIZENET_DATA_DIR/offline-pruning-filter-data
  "
  echo "Setting property \"offline-pruning-filter-data\" to \"$RIZENET_DATA_DIR/offline-pruning-filter-data\""
  set_property "offline-pruning-filter-data" "\"$RIZENET_DATA_DIR/offline-pruning-filter-data\""

  echo "Setting property \"state-sync-enabled\" to false"
  set_property "state-sync-enabled" false

  echo "Setting property \"state-sync-skip-resume\" to true"
  set_property "state-sync-skip-resume" true


  # print the C-Chain config after the changes:
  printf "\n\nC-Chain Blockchain config file \"$C_CHAIN_CONFIG\" before offline prunning:\n"
  cat $C_CHAIN_CONFIG
  printf "\nOwnership and permissions of file \"$C_CHAIN_CONFIG\" before offline prunning:\n"
  ls -lah $C_CHAIN_CONFIG

  # restart the node
  echo "Restarting the node to start offline prunning:"
  sudo systemctl restart avalanchego

  echo "Sleeping for 60 seconds"
  sleep 60

  # show if it is running correctly:
  echo "Avalanchego service status:"
  sudo systemctl status avalanchego --no-pager



  # Wait for the pruning process to complete by checking logs every minute
  echo "Waiting for offline pruning to complete..."
  while true; do

    # during progress it will print lines in the log like:
    # INFO [02-09|00:34:30.818] Pruning state data                       nodes=42,998,715 size=10.81GiB  elapsed=11m26.397s eta=14m49.961s
    # we show the user the whole line containing the elapsed time and the ETA:
    latest_log=$(sudo tail -n 500 /var/log/syslog)

    # Extract the pruning progress from latest_log
    prunning_progress=$(echo "$latest_log" | grep "Pruning state data" | tail -n 1)
    if [[ -n "$prunning_progress" ]]; then
      echo "Pruning progress: $prunning_progress"
    else
      # If no pruning progress found, check for iteration progress
      iteration_progress=$(echo "$latest_log" | grep "Iterating state snapshot" | tail -n 1)
      if [[ -n "$iteration_progress" ]]; then
        echo "Iteration progress: $iteration_progress"
      else
        iteration_progress=$(echo "$latest_log" | grep "Iterating state snapshot" | tail -n 1)
        echo "Printing last line of /var/log/syslog because we could not find prunning o iteration progress data:"
      fi
    fi

    # when it finishes it will log:
    # "Completed offline pruning. Re-initializing blockchain."
    # another line it will log contains the string below and data about how much was pruned. we want to
    # print the whole line that contains: "State pruning successful"
    # Check if pruning was successful and show the line
    if state_success_log_line=$(echo "$latest_log" | grep "State pruning successful"); then
      echo "Prunning successful! Offline pruning completed!"
      echo $state_success_log_line
      break
    fi

    # Check for completion of offline pruning with another tag
    if completed_prunning_log_line=$(echo $latest_log | grep "Completed offline pruning. Re-initializing blockchain."); then
      echo "Offline pruning completed! Prunning successful!"
      echo $completed_prunning_log_line
      break
    fi


    sleep 60  # Check every minute
  done

  # clean:
  echo "Cleaning by setting \"offline-pruning-enabled\" to false"
  set_property "offline-pruning-enabled" false







  # possibly delete:
  #   "state-sync-enabled"
  #   "state-sync-skip-resume"
  # echo "Removing properties for pruning cleanup."
  # jq --in-place 'del(.["allow-missing-tries", "offline-pruning-enabled", "state-sync-enabled", "state-sync-skip-resume"])' "$C_CHAIN_CONFIG"











  # print the final C-Chain config file:
  printf "\n\nC-Chain Blockchain config file \"$C_CHAIN_CONFIG\" after offline prunning:\n"
  cat $C_CHAIN_CONFIG
  printf "\nOwnership and permissions of file \"$C_CHAIN_CONFIG\" after offline prunning:\n"
  ls -lah $C_CHAIN_CONFIG


  # restart the node again
  echo "Restarting the node after offline prunning is done:"
  sudo systemctl restart avalanchego
  sleep 5

  # show if it is running correctly:
  echo "Avalanchego service status:"
  sudo systemctl status avalanchego --no-pager

  echo "Disk usage after enabling prunning:"
  df -h

fi
