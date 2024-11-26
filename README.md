# rizenet-node

Repository for validator nodes of the Rizenet blockchain, containing tools for easing node operation.

## Testnet Node deployment instructions for Ubuntu linux

Make sure you comply with the [Node Requirements](https://docs.rizenet.io/docs/rizenet/Rizenet%20Blockchain/validators/node_requirements)

```bash
# we suggest to clone the repository in the home folder of your user:
cd $HOME

# clone the repository:
git clone https://github.com/T-RIZE-Group/rizenet-node.git

# change directory into the downloaded repository
cd rizenet-node

# create your node's configuration file
cp config.sh myNodeConfig.sh

# review and edit the values in configuration file:
nano myNodeConfig.sh

# start the node creation process
sudo nohup bash ./automatedUbuntuTestnetDeployment.sh > $HOME/rizenet_node_deployment.log 2>&1 & tail -f $HOME/rizenet_node_deployment.log | sed '/DEPOYMENT_FINISHED/ q'
```

The process can take from a few hours to 48 hours, depending on your connection speed and the state of the network.

Once the execution is done, you will see something simmilar to the following:

```
Your node is ready to join the RizenetTestnet as a validator!

Please send the data below to your RizenetTestnet Admin contact so they can take care of staking to your node and sending the required transaction to the network.
Alternatively, you can do it yourself, in which case please contact your RizenetTestnet Admin contact so they can sign your transaction.

Node ID: 'NodeID-1BCy634gYiKRPtMBFdJJ3SRxuUywgXNHY'
Node BLS Public Key (nodePOP.publicKey): '0xc03228365aebb759626add06baa1deb17363f5fc1423ab1782fa1023793f5eaba3042c96066d0f7a29ec65a2ccd09649'
Node BLS Signature (proofOfPossession): '0x8833241b346bbcf96134e30e1a86ffcd96947d791234b5f5b811f5c54c1d42f6f28d01b3899e650740Bd7779b0fd60a007ef85371aeb31e5ade71991770c7126709aeb17df22f85cf4b947999689e35c787f49a2ffcb0ff6788c4adcac681a3d'
```

Please contact your admin contact point to onboard the node as a validator on the network.


## Testnet Node upgrade instructions for Ubuntu linux

For this first migration, please execute:
```bash
cd rizenet-node

# create your node's configuration file
BACKUPS_FOLDER=$HOME/rizenet-node-backups
mkdir -p $BACKUPS_FOLDER
cp config.sh $BACKUPS_FOLDER/nodeConfigBackupBeforeMigration1.sh

# reset any changes made to tracked files:
git reset --hard

# get the latest from git
git pull

# review and edit the values in configuration file. Make sure you review everything
# and change the value of the variable IS_CONFIG_READY to true:
cp config.sh myNodeConfig.sh
nano myNodeConfig.sh

# Clean the log file from the string that marks the end of it:
touch $HOME/rizenet_node_migrations.log
sed -i 's/MIGRATIONS_FINISHED/MIGRATION DONE/g' "$HOME/rizenet_node_migrations.log"

# start the node creation process
(sudo nohup bash ./executeMigrations.sh >> $HOME/rizenet_node_migrations.log 2>&1 & tail -f $HOME/rizenet_node_migrations.log | sed '/MIGRATIONS_FINISHED/ q')
```


