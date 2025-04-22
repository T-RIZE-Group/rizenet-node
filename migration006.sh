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


# # Function to check and set property in JSON with temporary file
# set_property() {
#   local property=$1
#   local value=$2

#   # Check if the property exists and modify it, else add the property with the value
#   if jq -e ".${property}" "$C_CHAIN_CONFIG" > /dev/null; then
#     jq ".${property} = ${value}" "$C_CHAIN_CONFIG" > "$C_CHAIN_CONFIG.tmp" && mv "$C_CHAIN_CONFIG.tmp" "$C_CHAIN_CONFIG"
#   else
#     jq ". + {\"${property}\": ${value}}" "$C_CHAIN_CONFIG" > "$C_CHAIN_CONFIG.tmp" && mv "$C_CHAIN_CONFIG.tmp" "$C_CHAIN_CONFIG"
#   fi
# code here to make files have the same ownership and permissions
# }

# Function to check and set property in JSON
set_property() {
  local property=$1
  local value=$2

  # Check if the property exists and modify it, else add the property with the value
  if jq -e ".${property}" "$C_CHAIN_CONFIG" > /dev/null; then
    jq --in-place ".${property} = ${value}" "$C_CHAIN_CONFIG"
  else
    jq --in-place ". + {\"${property}\": ${value}}" "$C_CHAIN_CONFIG"
  fi
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
  mkdir -p $RIZENET_DATA_DIR/offline-pruning-filter-data
  echo "Setting property \"offline-pruning-filter-data\" to \"$RIZENET_DATA_DIR/offline-pruning-filter-data\""
  set_property "offline-pruning-filter-data" "$RIZENET_DATA_DIR/offline-pruning-filter-data"

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
  sleep 5

  # show if it is running correctly:
  echo "Avalanchego service status:"
  sudo systemctl status avalanchego --no-pager



  # Wait for the pruning process to complete by checking logs every minute
  echo "Waiting for offline pruning to complete..."
  while true; do














    # during progress it will print lines in the log like:
    # INFO [02-09|00:34:30.818] Pruning state data                       nodes=42,998,715 size=10.81GiB  elapsed=11m26.397s eta=14m49.961s
    # we show the user the whole line containing the elapsed time and the ETA:
    log_line=$(sudo tail -n 100 /var/log/syslog | grep "Pruning state data")
    if [[ "$log_line" == *"Pruning state data"* ]]; then
      echo "Pruning progress: $log_line"
    fi

    latest_log=$(sudo tail -n 50 /var/log/syslog | grep "Pruning state data" | tail -n 1)
    if [[ -n "$latest_log" ]]; then
      echo "Pruning progress: $latest_log"
    fi












    # when it finishes it will log:
    # "Completed offline pruning. Re-initializing blockchain."
    # another line it will log contains the string below and data about how much was pruned. we want to print the whole line that contains:
    # "State pruning successful"
    latest_logs=$(sudo tail -n 100 /var/log/syslog)

    # Check if pruning was successful and show the line
    if state_success_log_line=$($latest_logs | grep "State pruning successful"); then
      echo $state_success_log_line
      break
    fi

    # Check for completion of offline pruning with another tag
    if $latest_logs | grep -q "Completed offline pruning. Re-initializing blockchain."; then
      echo "Offline pruning completed. Re-initializing blockchain."
      state_success_log_line=$($latest_logs | grep "State pruning successful")
      echo $state_success_log_line
      break
    fi


    sleep 60  # Check every minute
  done

  # clean:
  echo "Cleaning by setting \"allow-missing-tries\" to false"
  set_property "allow-missing-tries" false

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
