### START of variable declarations
azSub=$myAzSubId  # enter your own subscription ID string or set within global variable myAzSubId
azLoc=northeurope
azLocShort=eun
workload=sapdemo
rgName=${workload}-${azLocShort}-rg
vmAdminUser=bob
vnetName=${workload}-${azLocShort}-vnet
vnetAddressPrefix=10.20.0.0/24
subnetAddressPrefixApplication=10.20.0.0/25
subnetAddressPrefixDb=10.20.0.128/26

vmSapAscsSize=Standard_D4s_v3
vmSapAppSize=Standard_D4s_v3
vmSapDbSize=Standard_E4s_v3  
vmSapAscsName=${workload}-ascs-${azLocShort}-vm
vmSapAppName=${workload}-app-${azLocShort}-vm
vmSapDbName=${workload}-db-${azLocShort}-vm
vmImage=RedHat:RHEL-SAP:7.6:latest
# alternative to use SUSE
# vmImage=SUSE:SLES-SAP:12-SP4:latest
ppgName=${workload}-sid1-ppg

### END of variable declarations

az account set --subscription $azSub
az group create -g $rgName -l $azLoc

az network nsg create -g $rgName --name ${workload}-appl-${azLocShort}-nsg
az network nsg create -g $rgName --name ${workload}-db-${azLocShort}-nsg
az network vnet create --name $vnetName --address-prefixes $vnetAddressPrefix --subnet-name ${vnetName}-appl --subnet-prefixes $subnetAddressPrefixApplication --location $azLoc --resource-group $rgName 
az network vnet subnet create -g $rgName --name ${vnetName}-db  --vnet-name $vnetName --address-prefixes $subnetAddressPrefixDb --network-security-group ${workload}-db-${azLocShort}-nsg
az network vnet subnet update -g $rgName --name ${vnetName}-appl  --vnet-name $vnetName --network-security-group ${workload}-appl-${azLocShort}-nsg

az ppg create -g $rgName --name $ppgName --location $azLoc --type Standard

deploy_vm () {
    vmName=$1
    vmSize=$2
    subnetName=$3
    nicName=${vmName}_nic1
    az network nic create --name $nicName --resource-group $rgName --vnet-name $vnetName --subnet $subnetName --accelerated-networking true --public-ip-address ''
    az vm create --name $vmName --resource-group $rgName  --os-disk-name ${vmName}-osdisk --os-disk-size-gb 64 --storage-sku Premium_LRS --size $vmSize  --location $azLoc  --image $vmImage --admin-username=$vmAdminUser --nics $nicName --nsg '' --ppg $ppgName
}

# deploy ASCS
deploy_vm $vmSapAscsName $vmSapAscsSize ${vnetName}-appl
az vm disk attach -g $rgName --vm-name $vmName --name ${vmName}-datadisk0 --sku Premium_LRS --size 64 --lun 0 --new --caching None

# deploy Appserver
deploy_vm $vmSapAppName $vmSapAppSize ${vnetName}-appl
az vm disk attach -g $rgName --vm-name $vmName --name ${vmName}-datadisk0 --sku Premium_LRS --size 64 --lun 0 --new --caching None

# deploy DB
deploy_vm $vmSapDbName $vmSapDbSize ${vnetName}-db
az vm disk attach -g $rgName --vm-name $vmName --name ${vmName}-datadisk0 --sku Premium_LRS --size 128 --lun 0 --new --caching None
