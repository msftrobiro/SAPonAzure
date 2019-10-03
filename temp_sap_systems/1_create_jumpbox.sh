# what's needed before you start:
# 1) linux shell with generated ssh keys
# 2) have your subscription enabled to use availability zone for D and E series VMs in your chosen region (pick a region with zones, duh)
# 3) az cli installed in your linux shell (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-yum?view=azure-cli-latest)
#    you can also use Azure CloudShell for this step (https://azure.microsoft.com/en-us/features/cloud-shell)
# 4) you should have filled parameters.txt file as well, correctly and in correct lower/upper case for all parameters

#!/bin/bash

source parameters.txt
# create RG
az account set --subscription $AZSUB
RGNAME=RG-${AZLOCTLA}-${RESOURCEGROUP}
az group create --location $AZLOC --name $RGNAME

# create VNET and subnets
VNETNAME=VNET-${AZLOCTLA}-${RESOURCEGROUP}-hub
az network vnet create --name $VNETNAME --address-prefixes $HUBIP --subnet-name ${VNETNAME}-ssh --subnet-prefixes ${HUBIP} --location $AZLOC --resource-group $RGNAME
VNETNAME=VNET-${AZLOCTLA}-${RESOURCEGROUP}-sap
APPLSUBNET=`echo ${SAPIP}| awk -F / '{print $1}'`
az network vnet create --name $VNETNAME --address-prefixes $SAPIP --subnet-name ${VNETNAME}-appl --subnet-prefixes ${APPLSUBNET}/25 --location $AZLOC --resource-group $RGNAME
DBSUBNET=`echo $SAPIP|sed 's/.\{5\}$//'`
az network vnet subnet create --name ${VNETNAME}-db --resource-group $RGNAME --vnet-name $VNETNAME --address-prefixes ${DBSUBNET}.128/26
az network vnet list --resource-group $RGNAME --output table 

# create NSGs, needed for SAP VMs
SIDLOWER=`echo $SAPSID|awk '{print tolower($0)}'`
az network nsg create --resource-group $RGNAME --name NSG-${AZLOCTLA}-sap-${SIDLOWER}-ascs
az network nsg create --resource-group $RGNAME --name NSG-${AZLOCTLA}-sap-${SIDLOWER}-app
az network nsg create --resource-group $RGNAME --name NSG-${AZLOCTLA}-sap-${SIDLOWER}-db

# peer the hub and sap networks
VNETPEER=VNET-${AZLOCTLA}-${RESOURCEGROUP}
az network vnet peering create --resource-group $RGNAME --remote-vnet ${VNETPEER}-hub --vnet-name ${VNETPEER}-sap --name VNETPEER-${AZLOCTLA}-hub-to-sap --allow-vnet-access
az network vnet peering create --resource-group $RGNAME --remote-vnet ${VNETPEER}-sap --vnet-name ${VNETPEER}-hub --name VNETPEER-${AZLOCTLA}-sap-to-hub --allow-vnet-access


# create jumpbox VM
VNETNAME=VNET-${AZLOCTLA}-${RESOURCEGROUP}-sap
VMNAME=VM-${AZLOCTLA}-sap-jumpbox-lin
VMTYPE=Standard_D4s_v3
VMIMAGE=OpenLogic:CentOS:7.7:latest
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 127 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address-dns-name $JUMPFQDN --public-ip-address-allocation dynamic --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-ssh

# inside the VM
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${JUMPFQDN}.${AZLOC}.cloudapp.azure.com -i ${ADMINUSRSSH} << EOF
sudo yum update -y
sudo yum install -y jre xclock xauth screen
sudo su -
rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo
yum install azure-cli -y
reboot
EOF

# jumpbox is deployed
# some optional files being copied
echo "### waiting 45seconds for reboot ###"
sleep 45
scp -oStrictHostKeyChecking=no -i ~/.ssh/bob_azure -p /mnt/c/Users/robiro/OneDrive\ -\ Microsoft/SAP_on_Azure/_software/download_manager/DLManager.jar bob@core-sap-jumpbox.northeurope.cloudapp.azure.com:~ 
scp -oStrictHostKeyChecking=no -i ~/.ssh/bob_azure -p /mnt/c/Users/robiro/OneDrive\ -\ Microsoft/Azure/sockperf /mnt/c/Users/robiro/OneDrive\ -\ Microsoft/SAP_on_Azure/_software/hwcct_237.zip bob@core-sap-jumpbox.northeurope.cloudapp.azure.com:~ 
