# rizenet-node
Repository for validator nodes of the Rizenet blockchain


## Testnet Node deployment instructions for Ubuntu linux

```bash
# we suggest to clone the repository in the home folder of your user:
cd $HOME

# clone the repository:
git clone https://github.com/T-RIZE-Group/rizenet-node.git

# change directory into the downloaded repository
cd rizenet-node

# review and edit the values in configuration file:
nano config.sh

# start the node creation process
sudo nohup bash ./automatedUbuntuTestnetDeployment.sh > ./deployment.log 2>&1 & tail -f ./deployment.log
```

Once the execution is done, contact your admin contact point to onboard the node as a validator on the network.
