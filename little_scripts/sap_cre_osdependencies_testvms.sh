#!/bin/bash
azSub=$myAzSubId
azLoc=westeurope
azLocShort=euw
workload=saposdep
rgName=rg-${azLocShort}-${workload}
vmAdminUser=bob
vmSize=Standard_D2_v2
vnetName=vnet-${azLocShort}-${workload}
subnetName=${vnetName}_sub1
subnetAddressPrefix=10.240.0.0/25
vnetAddressPrefix=10.240.0.0/24

deploy_vm () {
    nicName=${vmName}_nic1
    az network public-ip create --name ${vmName}-pip --resource-group $rgName --dns-name ${vmName} --allocation-method dynamic 
    az network nic create --name $nicName --resource-group $rgName --vnet-name $vnetName --subnet $subnetName --accelerated-networking true --public-ip-address ${vmName}-pip
    az vm create --name $vmName --resource-group $rgName  --os-disk-name ${vmName}-osdisk --os-disk-size-gb 64 --storage-sku StandardSSD_LRS --size $vmSize  --location $azLoc  --image $vmImage --admin-username=$vmAdminUser --nics $nicName --priority Spot --max-price -1
}



az account set --subscription $azSub
az group create -g $rgName -l $azLoc

az network vnet create --name $vnetName --address-prefixes $vnetAddressPrefix --subnet-name $subnetName --subnet-prefixes $subnetAddressPrefix --location $azLoc --resource-group $rgName   

# RHEL PAYG
vmImage=RedHat:RHEL-SAP:7.6:latest
vmName=vm-${azLocShort}-${workload}-rhel-payg
deploy_vm

# RHEL BYOS
# vmImage=RedHat:rhel-byos:rhel-lvm76:latest
# vmName=vm-${azLocShort}-${workload}-rhel-byos
# deploy_vm

# SLES BYOS
vmImage=SUSE:sles-sap-15-sp1-byos:gen1:latest
vmName=vm-${azLocShort}-${workload}-sles-byos
deploy_vm

# SLES PAYG
vmImage=SUSE:sles-sap-15-sp1:gen1:latest
vmName=vm-${azLocShort}-${workload}-sles-payg
deploy_vm

az network public-ip list --resource-group $rgName|grep fqdn | awk '{print $2}'|sed 's/.\{2\}$//'|cut -c2-
ssh -oStrictHostKeyChecking=no ${vmAdminUser}@