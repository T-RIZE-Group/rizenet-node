#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh
# exactly as described in https://docs.rizenet.io/docs/rizenet/Rizenet%20Blockchain/validators/node_updating

# this migration disables IPv6 for nodes without a static IP address.
# this fixes an issue caused by nodes with dynamic IP being addressed
# as IPv6, which is not supported by the avalanche node software.
# The migrastion also sets the update frequency from the default 5 minutes
# to 1 minute between updates.

if [ "$HAS_DYNAMIC_IP" = "true" ]; then
  echo "Node is running with a dynamic IP. Editing settings!"

  # Check if "public-ip-resolution-service" exists. Exit if missing.
  if ! grep -q '"public-ip-resolution-service"' "$RIZENET_DATA_DIR/configs/avalanchego/config.json"; then
    echo "Error: \"public-ip-resolution-service\" not found in $RIZENET_DATA_DIR/configs/avalanchego/config.json."

  else
    # If "public-ip-resolution-frequency" exists, update its value; else insert it.
    if grep -q '"public-ip-resolution-frequency"' "$RIZENET_DATA_DIR/configs/avalanchego/config.json"; then
      # Replace existing line with the new value.
      echo "Updating public-ip-resolution-frequency to 1 minute in $RIZENET_DATA_DIR/configs/avalanchego/config.json"
      sed -i 's/"public-ip-resolution-frequency": "[^"]*",/"public-ip-resolution-frequency": "1m0s",/' "$RIZENET_DATA_DIR/configs/avalanchego/config.json"
    else
      # Append the new line immediately after the "public-ip-resolution-service" line.
      echo "Setting public-ip-resolution-frequency to 1 minute in $RIZENET_DATA_DIR/configs/avalanchego/config.json"
      sed -i '/"public-ip-resolution-service"/a\  "public-ip-resolution-frequency": "1m0s",' "$RIZENET_DATA_DIR/configs/avalanchego/config.json"
    fi
  fi


  # both ifconfigCo and opendns can return an IPv6 address, which is not supported by Avalanche.
  # for this reason, we must disable IPv6 on nodes with dynamic IP:
  # Function: update or add a sysctl setting
  update_sysctl_setting() {
    local setting="$1"  # e.g., net.ipv6.conf.all.disable_ipv6
    local value="$2"    # e.g., 1
    local line="${setting} = ${value}"

    # Check if the setting already exists
    if grep -q "^${setting}" "/etc/sysctl.conf"; then
      # Replace the line with the correct value if it's different
      sudo sed -i "s|^${setting}.*|${line}|g" "/etc/sysctl.conf"
    else
      # Append the setting if not found
      echo "${line}" | sudo tee -a "/etc/sysctl.conf" > /dev/null
    fi
  }

  # Update the IPv6 disabling settings
  echo "Disabling IPv6"
  update_sysctl_setting "net.ipv6.conf.all.disable_ipv6" "1"
  update_sysctl_setting "net.ipv6.conf.default.disable_ipv6" "1"

  # Reload sysctl settings
  echo "Reloading sysctl settings"
  sudo sysctl -p

  # restart the avalanchego service
  echo "Restarting the node service..."
  sudo systemctl restart avalanchego

  sleep 5;
  echo "Printing status of the node service:"
  sudo systemctl status avalanchego --no-pager

else
  echo "Node is NOT running with a dynamic IP. Leaving setting as is!"
fi
