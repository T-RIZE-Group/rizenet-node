#!/bin/bash

# Check if myNodeConfig.sh exists
if [ ! -f "$SCRIPT_DIR/myNodeConfig.sh" ]; then
  cp $SCRIPT_DIR/config.sh $SCRIPT_DIR/myNodeConfig.sh
  echo "The required file myNodeConfig.sh did not exist and was just created."
  echo -e "Please edit myNodeConfig.sh berfore running this script again. \n"
  exit 1
fi

# Source the myNodeConfig.sh script
echo -e "Sourcing config from $SCRIPT_DIR/myNodeConfig.sh \n"
source "$SCRIPT_DIR/myNodeConfig.sh"

# Check if IS_CONFIG_READY is set to "true"
if [ "$IS_CONFIG_READY" != "true" ]; then
  echo "The variable 'IS_CONFIG_READY' must be set to 'true' in 'myNodeConfig.sh', to indicate that you reviewed and updated your node config accordingly."
  echo -e "Please edit myNodeConfig.sh berfore running this script again. \n"
  exit 1
fi


# List of variables to check
vars_to_check=(
  HAS_DYNAMIC_IP
  P2P_PORT
  RPC_PORT
  CREATE_SWAP_FILE
  LIMIT_LOG_FILES_SPACE
  LOG_ROTATER_MAX_SIZE
  LOG_ROTATER_MAX_FILES
  USER_NAME
  GROUP_NAME
  USER_HOME
  HOME
  RIZENET_DATA_DIR
  REPOSITORY_PATH
  CHAIN_NAME
  GO_VERSION
  AVALANCHE_GO_VERSION
  SUBNET_EVM_VERSION
  NETWORK_ID
  AVALANCHE_NETWORK_FLAG
  SUBNET_ID
  CHAIN_ID
  SUBNET_VM_ID
  ENABLE_AUTOMATED_UBUNTU_SECURITY_UPDATES
  IS_CONFIG_READY
)

# Flag to track if any variables are missing
missing_vars=false

# Check each variable
for var in "${vars_to_check[@]}"; do
  value="${!var}"
  if [ -z "$value" ]; then
    echo "Variable '$var' is missing or empty."
    missing_vars=true
  fi
done

# Exit with error if any variables are missing
if [ "$missing_vars" = true ]; then
  echo -e "\nPlease set any missing variables in '$SCRIPT_DIR/myNodeConfig.sh'."
  echo -e "You can refer to the default value in the file '$SCRIPT_DIR/config.sh' \n"
  exit 1
else
  echo -e "All config values are set properly. Continuing with the execution... \n"
fi

