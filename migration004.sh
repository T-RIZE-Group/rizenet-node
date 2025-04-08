#!/bin/bash

# do NOT execute this script directly. Instead, run executeMigrations.sh

# this migration will:
# 1. Change the listen address in the node exporter service file
# 2. Setup Json Exporter

#################################################################
# Changing the listen address in the node exporter service file #
#################################################################

# Define the service file path
DEFAULT_SERVICE_FILE="/etc/systemd/system/node_exporter.service"
# Define the default port for json exporter
DEFAULT_JSON_EXPORTER_PORT=7979

# Define the default port for node exporter
DEFAULT_NODE_EXPORTER_PORT=9100

# Ask for node exporter service file path
read -rp "📄 Path to node exporter service (default: $DEFAULT_SERVICE_FILE): " SERVICE_FILE
SERVICE_FILE=${SERVICE_FILE:-$DEFAULT_SERVICE_FILE}

if [[ ! -f "$SERVICE_FILE" ]]; then
  echo "❌ File not found: $SERVICE_FILE"
  exit 1
fi

# Check if the file exists
if [ ! -f "$SERVICE_FILE" ]; then
  echo "❌ Service file not found: $SERVICE_FILE"
  exit 1
fi

# Prompt the user for the Json Exporter port number
read -p "Enter the json exporter port number (default is $DEFAULT_JSON_EXPORTER_PORT): " DEFAULT_JSON_EXPORTER_PORT
JSON_EXPORTER_PORT=${JSON_EXPORTER_PORT:-$DEFAULT_JSON_EXPORTER_PORT}

# Prompt the user for the Node Exporter port number
read -p "Enter the node exporter port number (default is $DEFAULT_NODE_EXPORTER_PORT): " DEFAULT_NODE_EXPORTER_PORT
NODE_EXPORTER_PORT=${NODE_EXPORTER_PORT:-$DEFAULT_NODE_EXPORTER_PORT}

LISTEN_IP='0.0.0.0'

# Replace the listen address
sudo sed -i "s|.*--web.listen-address=.*|    --web.listen-address=${LISTEN_IP}:${NODE_EXPORTER_PORT} \\\\|" "$SERVICE_FILE"

# Reload systemd and restart node_exporter
sudo systemctl daemon-reload
sudo systemctl restart node_exporter

echo "✅ node_exporter service updated and restarted"


#################################################################
#                   Setup Json Exporter                         #
#################################################################

# Step 1: Clone the json_exporter repository
echo "Checking if json_exporter repository exists..."
if [ ! -d "json_exporter" ]; then
  echo "Cloning json_exporter repository..."
  git clone https://github.com/prometheus-community/json_exporter.git
else
  echo "json_exporter repository already exists. Skipping clone."
fi

cd json_exporter/

# Step 2: Install necessary dependencies
echo "Installing make..."
sudo apt update
sudo apt install -y make

# Step 3: Build the json_exporter
echo "Building json_exporter..."
make build

# Step 4: Modify the config.yml
echo "Modifying config.yml..."

# If the user doesn't enter anything, use the default port
if [ "$JSON_EXPORTER_PORT" -eq "$DEFAULT_JSON_EXPORTER_PORT" ]; then

  # Create the config.yml file without the web section
  cat <<EOL > examples/config.yml
modules:
  default:
    metrics:
    - name: node_healthy
      path: '{ .healthy }'
      help: healthy is true all the health checks are passing
EOL
else
  # Create the config.yml file with the custom port in the web section
  cat <<EOL > examples/config.yml
web:
  listen-address: ":$USER_PORT"
modules:
  default:
    metrics:
    - name: node_healthy
      path: '{ .healthy }'
      help: healthy is true all the health checks are passing
EOL
fi

# Step 5: Create the systemd service for json_exporter
echo "Creating systemd service for json_exporter..."
JSON_EXPORTER_HOME=$(sudo find / -type d -name "json_exporter" 2>/dev/null)

sudo tee /etc/systemd/system/json_exporter.service > /dev/null <<EOL
[Unit]
Description=Prometheus JSON Exporter
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${JSON_EXPORTER_HOME}
ExecStart=${JSON_EXPORTER_HOME}/json_exporter --config.file ${JSON_EXPORTER_HOME}/examples/config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# Step 6: Reload systemd, restart, enable and check the service
echo "Reloading systemd and restarting json_exporter..."
sudo systemctl daemon-reload
sudo systemctl restart json_exporter
sudo systemctl enable json_exporter

echo "✅ json_exporter setup complete!"