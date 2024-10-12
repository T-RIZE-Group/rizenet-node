# rizenet-node
Repository for validator nodes of the Rizenet blockchain


## Deployment:

```bash

# we suggest to place the directory in the home folder of your user:
cd $HOME

# clone the repository:
git clone https://github.com/T-RIZE-Group/rizenet-node.git

# change directory into the downloaded repository
cd rizenet-node

# start the node creation process
sudo nohup bash ./automatedUbuntuTestnetDeployment.sh > ./deployment.log 2>&1 & tail -f ./deployment.log

```