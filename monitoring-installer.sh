#!/bin/bash
# Does a multi-step installation of Prometheus, Grafana, node_exporter and Avalanche dashboards
# Intended for non-technical validators, assumes running on compatible Ubuntu.

#helper function that prints usage
usage () {
  echo "Usage: $0 [--1|--2|--3|--4|--5|--help]"
  echo ""
  echo "Options:"
  echo "   --help   Shows this message"
  echo "   --1      Step 1: Installs Prometheus"
  echo "   --2      Step 2: Installs Grafana"
  echo "   --3      Step 3: Installs node_exporter"
  echo "   --4      Step 4: Installs AvalancheGo Grafana dashboards"
  echo "   --5      Step 5: (Optional) Installs additional dashboards"
  echo ""
}

#helper function to check for presence of required commands, and install if missing
check_reqs () {
  if Sudo -E -u "$USER_NAME" bash -c "command -v curl" &> /dev/null
  then
      echo "curl could not be found, will install..."
      sudo DEBIAN_FRONTEND=noninteractive apt-get install curl -y
  fi
  if Sudo -E -u "$USER_NAME" bash -c "command -v wget" &> /dev/null
  then
      echo "wget could not be found, will install..."
      sudo DEBIAN_FRONTEND=noninteractive apt-get install wget -y
  fi
}

#helper function to check for supported environment
get_environment() {
  echo "Checking environment..."
  check_reqs
  export foundArch="$(uname -m)"                         #get system architecture
  export foundOS="$(uname)"                              #get OS
  if [ "$foundOS" != "Linux" ]; then
    #sorry, don't know you.
    echo "FATAL ERROR: Unsupported operating system: $foundOS!"
  fi
  if [ "$foundArch" = "aarch64" ]; then
    export getArch="arm64"                               #we're running on arm arch (probably RasPi)
    echo "Found arm64 architecture..."
  elif [ "$foundArch" = "x86_64" ]; then
    export getArch="amd64"                               #we're running on intel/amd
    echo "Found amd64 architecture..."
  else
    #sorry, don't know you.
    echo "FATAL ERROR: Unsupported architecture: $foundArch!"
  fi
}

install_prometheus() {
  echo "AvalancheGo monitoring installer"
  echo "--------------------------------"
  echo "STEP 1: Installing Prometheus"
  echo
  get_environment
  check_reqs
  sudo -E -u "$USER_NAME" bash -c 'mkdir -p /tmp/avalanche-monitoring-installer/prometheus'
  cd /tmp/avalanche-monitoring-installer/prometheus
  # prometheus 3 breaks compatibility with the setup prepared by avalanche, so we download a specific version:
  # export promFileName="$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep -o "http.*linux-$getArch\.tar\.gz")"
  export promFileName="https://github.com/prometheus/prometheus/releases/download/v$PROMETEHUS_VERSION/prometheus-$PROMETEHUS_VERSION.linux-amd64.tar.gz"

  if [[ $(wget -S --spider "$promFileName"  2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
    echo "Prometheus install archive found: $promFileName"
  else
    echo "Fatal ERROR: Unable to find Prometheus install archive."
  fi
  echo "Attempting to download: $promFileName"
  sudo -E -u "$USER_NAME" bash -c 'wget -nv -O prometheus.tar.gz "$promFileName"'
  sudo -E -u "$USER_NAME" bash -c 'mkdir -p prometheus'
  sudo -E -u "$USER_NAME" bash -c "tar xvf prometheus.tar.gz -C prometheus --strip-components=1"
  echo "Installing..."
  id -u prometheus &>/dev/null || sudo useradd -M -r -s /bin/false prometheus
  echo "Making a dir for prometheus:"
  sudo mkdir -p /etc/prometheus /var/lib/prometheus
  echo "Installing apt dependencies:"
  sudo sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https software-properties-common
  echo "Changing dir to prometheus:"
  cd prometheus
  echo "Copying executable to bin folder..."
  cp {prometheus,promtool} /usr/local/bin/
  echo "Setting ownership of files..."
  chown prometheus:prometheus /usr/local/bin/{prometheus,promtool}
  chown -R prometheus:prometheus /etc/prometheus
  chown prometheus:prometheus /var/lib/prometheus
  echo "Copying config..."
  cp -r {consoles,console_libraries} /etc/prometheus/
  cp prometheus.yml /etc/prometheus/

  #creating the service file
  echo "Creating the prometheus service file:"
  sudo -E -u "$USER_NAME" bash -c 'touch prometheus.service'
  {
    echo "[Unit]"
    echo "Description=Prometheus"
    echo "Documentation=https://prometheus.io/docs/introduction/overview/"
    echo "Wants=network-online.target"
    echo "After=network-online.target"
    echo ""
    echo "[Service]"
    echo "Type=simple"
    echo "User=prometheus"
    echo "Group=prometheus"
    echo "ExecReload=/bin/kill -HUP \$MAINPID"
    echo "ExecStart=/usr/local/bin/prometheus   --config.file=/etc/prometheus/prometheus.yml   --storage.tsdb.path=/var/lib/prometheus   --web.console.templates=/etc/prometheus/consoles   --web.console.libraries=/etc/prometheus/console_libraries   --web.listen-address=127.0.0.1:9090   --web.external-url="
    echo ""
    echo "SyslogIdentifier=prometheus"
    echo "Restart=always"
    echo ""
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } > prometheus.service
  cp prometheus.service /etc/systemd/system/prometheus.service

  echo "Creating Prometheus service..."
  systemctl daemon-reload
  systemctl stop prometheus
  sleep 10;
  systemctl start prometheus
  systemctl enable prometheus

  echo
  echo "Done!"
  echo
  echo "Prometheus service should be up and running now."
  echo "To check that the service is running use the following command:"
  echo "systemctl status prometheus --no-pager"
  echo
  echo
  echo "You can also check Prometheus web interface, available on http://your-node-host-ip:9090/"
  echo
  echo "If everything looks ok you can now continue with installing Grafana."

  echo "returning from install_prometheus..."
  return;
}

install_grafana() {
  echo "AvalancheGo monitoring installer"
  echo "--------------------------------"
  echo "STEP 2: Installing Grafana"
  echo
  sudo mkdir -p /etc/apt/keyrings/
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee -a /etc/apt/sources.list.d/grafana.list
  echo "running sudo DEBIAN_FRONTEND=noninteractive apt-get for grafana..."
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install grafana -y


  # Update Grafana port setting in /etc/grafana/grafana.ini to use the desired port for grafana
  # Look for the [server] block; if it exists, then either update or add the http_port setting inside that block.
  if grep -q "^\[server\]" /etc/grafana/grafana.ini; then
    # Check if an http_port setting exists (possibly commented with ';')
    if sudo sed -n '/^\[server\]/,/^\[/{/^[[:space:]]*;*[[:space:]]*http_port[[:space:]]*=/p}' /etc/grafana/grafana.ini | grep -q .; then
      # Replace the existing http_port line (whether commented or not) with the desired port
      sudo sed -i '/^\[server\]/,/^\[/{s/^[[:space:]]*;*[[:space:]]*http_port[[:space:]]*=.*/http_port = '"$GRAFANA_PORT"'/;}' /etc/grafana/grafana.ini
    else
      # Append the http_port setting right after the [server] header if it is missing
      sudo sed -i '/^\[server\]/a http_port = '"$GRAFANA_PORT"'' /etc/grafana/grafana.ini
    fi
  else
    # If there is no [server] block, append one with the http_port setting at the end of the file
    echo -e "\n[server]\nhttp_port = $GRAFANA_PORT" | sudo tee -a /etc/grafana/grafana.ini
  fi

  echo "Starting Grafana service..."
  systemctl daemon-reload
  systemctl stop grafana-server
  sleep 10;
  systemctl start grafana-server
  systemctl enable grafana-server.service

  echo
  echo "Done!"
  echo
  echo "Grafana service should be up and running now."
  echo "To check that the service is running use the following command:"
  echo "systemctl status grafana-server --no-pager"
  echo
  echo
  echo "You can also check Grafana web interface, available on http://your-node-host-ip:3000/"
  echo
  echo "Now you need to set up Prometheus as a data source for Grafana."

  echo "returning from install_grafana..."
  return;
}

install_exporter() {
  echo "AvalancheGo monitoring installer"
  echo "--------------------------------"
  echo "STEP 3: Installing node_exporter"
  echo
  get_environment
  sudo -E -u "$USER_NAME" bash -c 'mkdir -p /tmp/avalanche-monitoring-installer/exporter_archive'
  cd /tmp/avalanche-monitoring-installer/exporter_archive
  echo "Dowloading archive..."
  export nodeFileName="$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep -o "http.*linux-$getArch\.tar\.gz")"
  echo $nodeFileName
  sudo -E -u "$USER_NAME" bash -c 'wget -nv -O node_exporter.tar.gz "$nodeFileName"'
  sudo -E -u "$USER_NAME" bash -c 'tar xvf node_exporter.tar.gz -C /tmp/avalanche-monitoring-installer/exporter_archive --strip-components=1'
  mv /tmp/avalanche-monitoring-installer/exporter_archive/node_exporter /usr/local/bin
  echo "Installed, version:"
  sudo -E -u "$USER_NAME" bash -c 'node_exporter --version'
  echo
  echo "Creating service..."

  sudo -E -u "$USER_NAME" bash -c 'touch node_exporter.service'
  {
    echo "[Unit]"
    echo "Description=Node exporter"
    echo "Documentation=https://github.com/prometheus/node_exporter"
    echo "Wants=network-online.target"
    echo "After=network-online.target"
    echo ""
    echo "[Service]"
    echo "Type=simple"
    echo "User=prometheus"
    echo "Group=prometheus"
    echo "ExecReload=/bin/kill -HUP \$MAINPID"
    echo "ExecStart=/usr/local/bin/node_exporter \\"
    echo "    --collector.cpu \\"
    echo "    --collector.diskstats \\"
    echo "    --collector.filesystem \\"
    echo "    --collector.loadavg \\"
    echo "    --collector.meminfo \\"
    echo "    --collector.filefd \\"
    echo "    --collector.netdev \\"
    echo "    --collector.stat \\"
    echo "    --collector.netstat \\"
    echo "    --collector.systemd \\"
    echo "    --collector.uname \\"
    echo "    --collector.vmstat \\"
    echo "    --collector.time \\"
    echo "    --collector.mdadm \\"
    echo "    --collector.zfs \\"
    echo "    --collector.tcpstat \\"
    echo "    --collector.bonding \\"
    echo "    --collector.hwmon \\"
    echo "    --collector.arp \\"
    echo "    --web.listen-address=127.0.0.1:9100 \\"
    echo "    --web.telemetry-path=\"/metrics\""
    echo ""
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >node_exporter.service
  cp node_exporter.service /etc/systemd/system/node_exporter.service

  systemctl daemon-reload
  systemctl stop node_exporter
  sleep 10;
  systemctl start node_exporter
  systemctl enable node_exporter

  echo "Finishing configuration..."

  sudo -E -u "$USER_NAME" bash -c 'cp /etc/prometheus/prometheus.yml .'
  sudo -E -u "$USER_NAME" bash -c 'touch prometheus.yml'
  if ! grep -q "job_name: 'avalanchego'" prometheus.yml; then
    {
      echo "  - job_name: 'avalanchego'"
      echo "    metrics_path: '/ext/metrics'"
      echo "    static_configs:"
      echo "      - targets: ['localhost:$RPC_PORT']"
    } >> prometheus.yml
  fi
  if ! grep -q "job_name: 'avalanchego-machine'" prometheus.yml; then
    {
      echo "  - job_name: 'avalanchego-machine'"
      echo "    static_configs:"
      echo "      - targets: ['localhost:9100']"
      echo "        labels:"
      echo "          alias: 'machine'"
    } >> prometheus.yml
  fi
  cp prometheus.yml /etc/prometheus/
  systemctl restart prometheus
  echo
  echo "Done!"
  echo
  echo "Node_exporter service should be up and running now."
  echo "To check that the service is running use the following command:"
  echo "systemctl status node_exporter --no-pager"
  echo
  echo
  echo "Now you need to set up Grafana dashboards next."

  echo "returning from install_exporter..."
  return;
}

install_dashboards() {
  #check for installation
  if sudo -E -u "$USER_NAME" bash -c 'test -f "/etc/grafana/grafana.ini"'; then
    echo "AvalancheGo monitoring installer"
    echo "--------------------------------"
  else
    echo "Node monitoring installation not found for install_dashboards!"
  fi

  if sudo -E -u "$USER_NAME" bash -c 'test -f "/etc/grafana/provisioning/dashboards/avalanche.yaml"'; then
    echo "STEP 4: Installing Grafana dashboards"
    export provisioningDone=true
    echo
    echo "Dashboards already provisioned, switching to upgrade mode."
  else
    export provisioningDone=false
  fi

  echo
  echo "Downloading dashboards..."
  sudo -E -u "$USER_NAME" bash -c 'mkdir -p /tmp/avalanche-monitoring-installer/dashboards-install'
  cd /tmp/avalanche-monitoring-installer/dashboards-install

  sudo -E -u "$USER_NAME" bash -c 'wget -nd -m -nv https://raw.githubusercontent.com/ava-labs/avalanche-monitoring/master/grafana/dashboards/c_chain.json'
  sudo -E -u "$USER_NAME" bash -c 'wget -nd -m -nv https://raw.githubusercontent.com/ava-labs/avalanche-monitoring/master/grafana/dashboards/database.json'
  sudo -E -u "$USER_NAME" bash -c 'wget -nd -m -nv https://raw.githubusercontent.com/ava-labs/avalanche-monitoring/master/grafana/dashboards/machine.json'
  sudo -E -u "$USER_NAME" bash -c 'wget -nd -m -nv https://raw.githubusercontent.com/ava-labs/avalanche-monitoring/master/grafana/dashboards/main.json'
  sudo -E -u "$USER_NAME" bash -c 'wget -nd -m -nv https://raw.githubusercontent.com/ava-labs/avalanche-monitoring/master/grafana/dashboards/network.json'
  sudo -E -u "$USER_NAME" bash -c 'wget -nd -m -nv https://raw.githubusercontent.com/ava-labs/avalanche-monitoring/master/grafana/dashboards/p_chain.json'
  sudo -E -u "$USER_NAME" bash -c 'wget -nd -m -nv https://raw.githubusercontent.com/ava-labs/avalanche-monitoring/master/grafana/dashboards/x_chain.json'
  if sudo -E -u "$USER_NAME" bash -c 'test -f "/etc/grafana/dashboards/subnets.json"'; then
    sudo -E -u "$USER_NAME" bash -c 'wget -nd -m -nv https://raw.githubusercontent.com/ava-labs/avalanche-monitoring/master/grafana/dashboards/subnets.json'
  fi

  sudo mkdir -p /etc/grafana/dashboards
  cp *.json /etc/grafana/dashboards

  if [ "$provisioningDone" = "false" ]; then
    echo
    echo "Provisioning dashboards..."
    sudo -E -u "$USER_NAME" bash -c 'touch avalanche.yaml'
    {
      echo "apiVersion: 1"
      echo ""
      echo "providers:"
      echo "  - name: 'Avalanche official'"
      echo "    orgId: 1"
      echo "    folder: ''"
      echo "    folderUid: ''"
      echo "    type: file"
      echo "    disableDeletion: false"
      echo "    updateIntervalSeconds: 30"
      echo "    allowUiUpdates: true"
      echo "    options:"
      echo "      path: /etc/grafana/dashboards"
      echo "      foldersFromFilesStructure: true"
    } > avalanche.yaml
    cp avalanche.yaml /etc/grafana/provisioning/dashboards/
    echo "Provisioning datasource..."
    sudo -E -u "$USER_NAME" bash -c 'touch prom.yaml'
    {
      echo "apiVersion: 1"
      echo ""
      echo "datasources:"
      echo "  - name: Prometheus"
      echo "    type: prometheus"
      echo "    access: proxy"
      echo "    orgId: 1"
      echo "    url: http://localhost:9090"
      echo "    isDefault: true"
      echo "    version: 1"
      echo "    editable: false"
    } > prom.yaml
    cp prom.yaml /etc/grafana/provisioning/datasources/
    systemctl restart grafana-server
  fi
  echo
  echo "Done!"
  echo
  echo "AvalancheGo Grafana dashboards have been installed and updated."
  echo "It might take up to 30s for new versions to show up in Grafana."

  echo "returning from install_dashboards..."
  return;
}

install_extras() {
  #check for installation
  if sudo -E -u "$USER_NAME" bash -c 'test -f "/etc/grafana/grafana.ini"'; then
    echo "AvalancheGo monitoring installer"
    echo "--------------------------------"
  else
    echo "Node monitoring installation not found for install_extras!"
  fi

  echo "STEP 5: Installing additional dashboards"
  echo
  echo "Downloading..."
  sudo -E -u "$USER_NAME" bash -c 'mkdir -p /tmp/avalanche-monitoring-installer/dashboards-install'
  cd /tmp/avalanche-monitoring-installer/dashboards-install

  sudo -E -u "$USER_NAME" bash -c 'wget -nd -m -nv https://raw.githubusercontent.com/ava-labs/avalanche-monitoring/master/grafana/dashboards/subnets.json'

  sudo mkdir -p /etc/grafana/dashboards
  cp subnets.json /etc/grafana/dashboards

  echo
  echo "Done!"
  echo
  echo "Additional Grafana dashboards have been installed and updated."
  echo "It might take up to 30s for new versions to show up in Grafana."

  echo "returning from install_extras..."
  return;
}

if [ $# -ne 0 ] #arguments check
then
  case $1 in
    --1) #install prometheus
      install_prometheus
          ;;
    --2) #install grafana
      install_grafana
          ;;
    --3) #install node_exporter
      install_exporter
          ;;
    --4) #install AvalancheGo dashboards
      install_dashboards
          ;;
    --5) #install extra dashboards
      install_extras
          ;;
    --help)
      usage
          ;;
  esac
else
  usage
fi

