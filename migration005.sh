#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh
# exactly as described in https://docs.rizenet.io/docs/rizenet/Rizenet%20Blockchain/validators/node_updating

# this migration disables IPv6 for nodes without a static IP address.
# this fixes an issue caused by nodes with dynamic IP being addressed
# as IPv6, which is not supported by the avalanche node software.
# The migrastion also sets the update frequency from the default 5 minutes
# to 1 minute between updates.

if [ "$HAS_DYNAMIC_IP" = "true" ]; then
  # don't include the publicIp variable, because on a node with dynamic IP this changes:
  publicIp=''

  # We use a service to resolve the dynamic public IP. When this value is provided,
  # the node will use that service to periodically resolve/update its public IP.
  # Only acceptable values are ifconfigCo, opendns:
  publicIpResolutionService='"public-ip-resolution-service": "ifconfigCo",'

  # Change the public IP update frequency from the default of 5 minutes to 1 minute:
  publicIpResolutionFrequency='"public-ip-resolution-frequency": "1m0s",'

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
  update_sysctl_setting "net.ipv6.conf.all.disable_ipv6" "1"
  update_sysctl_setting "net.ipv6.conf.default.disable_ipv6" "1"

  # Reload sysctl settings
  sudo sysctl -p

fi




# update the migration version in the migration file
export MIGRATION_ID=5
sed -i "1s/.*/$MIGRATION_ID/" "$MIGRATION_FILE"
