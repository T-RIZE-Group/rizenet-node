#!/bin/bash
set -e

# do NOT execute this script directly. Instead, run executeMigrations.sh

# this migration will:
# 1. Change the listen address in the node exporter service file
# 2. Setup Json Exporter

#################################################################
# Changing the listen address in the node exporter service file #
#################################################################

# Source the myNodeConfig.sh file from the same directory
echo "loading myNodeConfig.sh"
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || realpath "$0" 2>/dev/null)")
echo "Sourcing config from $SCRIPT_DIR/myNodeConfig.sh"
source "$SCRIPT_DIR/myNodeConfig.sh"

# Check if myNodeConfig.sh already contains a line with NODE_EXPORTER_SERVICE_FILE_PATH=
if ! grep -q '^export NODE_EXPORTER_SERVICE_FILE_PATH=' "$SCRIPT_DIR/myNodeConfig.sh"; then
  # Append the new value line if not found
  echo '' >> "$SCRIPT_DIR/myNodeConfig.sh"
  echo '# node monitoring:' >> "$SCRIPT_DIR/myNodeConfig.sh"
  echo 'Adding NODE_EXPORTER_SERVICE_FILE_PATH="/etc/systemd/system/node_exporter.service" to $SCRIPT_DIR/myNodeConfig.sh'
  echo 'export NODE_EXPORTER_SERVICE_FILE_PATH="/etc/systemd/system/node_exporter.service"' >> "$SCRIPT_DIR/myNodeConfig.sh"
  # Reload the config to make sure new vars are available immediately
  source "$SCRIPT_DIR/myNodeConfig.sh"
fi

# Check if myNodeConfig.sh already contains a line with JSON_EXPORTER_PORT=
if ! grep -q '^export JSON_EXPORTER_PORT=' "$SCRIPT_DIR/myNodeConfig.sh"; then
  # Append the new value line if not found
  echo '' >> "$SCRIPT_DIR/myNodeConfig.sh"
  echo '# node monitoring:' >> "$SCRIPT_DIR/myNodeConfig.sh"
  echo 'Adding JSON_EXPORTER_PORT=7979 to $SCRIPT_DIR/myNodeConfig.sh'
  echo 'export JSON_EXPORTER_PORT=7979' >> "$SCRIPT_DIR/myNodeConfig.sh"
  # Reload the config to make sure new vars are available immediately
  source "$SCRIPT_DIR/myNodeConfig.sh"
fi

# Check if myNodeConfig.sh already contains a line with NODE_EXPORTER_PORT=
if ! grep -q '^export NODE_EXPORTER_PORT=' "$SCRIPT_DIR/myNodeConfig.sh"; then
  # Append the new value line if not found
  echo '' >> "$SCRIPT_DIR/myNodeConfig.sh"
  echo '# node monitoring:' >> "$SCRIPT_DIR/myNodeConfig.sh"
  echo 'Adding NODE_EXPORTER_PORT=9100 to $SCRIPT_DIR/myNodeConfig.sh'
  echo 'export NODE_EXPORTER_PORT=9100' >> "$SCRIPT_DIR/myNodeConfig.sh"
  # Reload the config to make sure new vars are available immediately
  source "$SCRIPT_DIR/myNodeConfig.sh"
fi


# Check if the file exists
if [ ! -f "$NODE_EXPORTER_SERVICE_FILE_PATH" ]; then
  echo "❌ Service file not found: $NODE_EXPORTER_SERVICE_FILE_PATH"
  exit 1
fi



LISTEN_IP='0.0.0.0'

# Replace the listen address
sed -i "s|.*--web.listen-address=.*|    --web.listen-address=${LISTEN_IP}:${NODE_EXPORTER_PORT} \\\\|" "$NODE_EXPORTER_SERVICE_FILE_PATH"

# Reload systemd and restart node_exporter
systemctl daemon-reload
systemctl restart node_exporter

echo "✅ node_exporter service updated and restarted"


#################################################################
#                   Setup Json Exporter                         #
#################################################################

# Step 1: Clone the json_exporter repository
JSON_EXPORTER_HOME="/opt/json_exporter"

echo "Checking if json_exporter repository exists..."
if [ ! -d "$JSON_EXPORTER_HOME/.git" ]; then
    echo "Cloning json_exporter repository..."
    mkdir -p /opt/json_exporter
    chown $USER_NAME:$USER_NAME /opt/json_exporter
    cd /opt/json_exporter
    sudo -u "$USER_NAME" bash -lc "git clone https://github.com/prometheus-community/json_exporter.git ."
else
  echo "json_exporter repository already exists. Skipping clone."
fi

cd $JSON_EXPORTER_HOME

# Step 2: Install necessary dependencies
echo "Installing make..."
apt update
apt install -y make

# Step 3: Build the json_exporter
echo 'export PATH=$PATH:/usr/local/go/bin' | tee -a /home/${USER_NAME}/.profile
echo "Building json_exporter..."
sudo -u "$USER_NAME" bash -lc "make build"

# Step 4: Modify the config.yml
echo "Modifying config.yml..."

# Create the config.yml file
cat <<EOL > examples/config.yml
modules:
  default:
    metrics:
    - name: node_healthy
      path: '{ .healthy }'
      help: healthy is true all the health checks are passing
EOL

# Step 5: Create the systemd service for json_exporter
echo "Creating systemd service for json_exporter..."

tee /etc/systemd/system/json_exporter.service > /dev/null <<EOL
[Unit]
Description=Prometheus JSON Exporter
After=network.target

[Service]
Type=simple
User=${USER_NAME}
WorkingDirectory=${JSON_EXPORTER_HOME}
ExecStart=${JSON_EXPORTER_HOME}/json_exporter \
  --config.file ${JSON_EXPORTER_HOME}/examples/config.yml \
  --web.listen-address ":${JSON_EXPORTER_PORT}"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# Step 6: Reload systemd, restart, enable and check the service
echo "Reloading systemd and restarting json_exporter..."
systemctl daemon-reload
systemctl restart json_exporter
systemctl enable json_exporter

echo "✅ json_exporter setup complete!"

