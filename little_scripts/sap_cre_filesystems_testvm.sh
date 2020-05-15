azSub=$mySubId
azLoc=northeurope
azLocShort=eun
workload=crefs
rgName=rg-${azLocShort}-${workload}
vmAdminUser=bob
vmName=vm-${azLocShort}-${workload}
vmSize=Standard_M64s
vmImage=RedHat:RHEL-SAP:7.6:latest
#vmImage=SUSE:SLES-SAP:12-SP4:latest
vnetName=vnet-${azLocShort}-${workload}
nicName=${vmName}_nic1
subnetName=${vnetName}_sub1
subnetAddressPrefix=10.240.0.0/25
vnetAddressPrefix=10.240.0.0/24
hanaProdStorage=1
hanaProdStorageUltra=0
hanaDataDisksCount=8
hanaLogDisksCount=2
hanaBackupDisksCount=4


az account set --subscription $azSub
az group create -g $rgName -l $azLoc

az network vnet create --name $vnetName --address-prefixes $vnetAddressPrefix --subnet-name $subnetName --subnet-prefixes $subnetAddressPrefix --location $azLoc --resource-group $rgName   



if [[ $hanaProdStorage -eq '1' && $hanaProdStorageUltra -eq '1' ]]; then
az network public-ip create --name ${vmName}-pip --resource-group $rgName --dns-name ${vmName}-${RANDOM} --allocation-method dynamic --zone 1
az network nic create --name $nicName --resource-group $rgName --vnet-name $vnetName --subnet $subnetName --accelerated-networking true --public-ip-address ${vmName}-pip
az vm create --name $vmName --resource-group $rgName  --os-disk-name ${vmName}-osdisk --os-disk-size-gb 64 --storage-sku Premium_LRS --size $vmSize  --location $azLoc  --image $vmImage --admin-username=$vmAdminUser --nics $nicName --ultra-ssd-enabled true --zone 1 --priority Spot --max-price -1
else
az network public-ip create --name ${vmName}-pip --resource-group $rgName --dns-name ${vmName}curl-${RANDOM} --allocation-method dynamic
az network nic create --name $nicName --resource-group $rgName --vnet-name $vnetName --subnet $subnetName --accelerated-networking true --public-ip-address ${vmName}-pip
az vm create --name $vmName --resource-group $rgName  --os-disk-name ${vmName}-osdisk --os-disk-size-gb 64 --storage-sku Premium_LRS --size $vmSize  --location $azLoc  --image $vmImage --admin-username=$vmAdminUser --nics $nicName --priority Spot --max-price -1
fi

hanaDataDisksTotalCount=$((hanaDataDisksCount+hanaLogDisksCount+hanaBackupDisksCount+2)) # +2 for shared+usrsap
az vm disk attach --resource-group $rgName --vm-name $vmName --name ${vmName}-datadisk0 --sku Premium_LRS --size 64 --lun 0 --new --caching ReadOnly # /usr/sap
az vm disk attach --resource-group $rgName --vm-name $vmName --name ${vmName}-datadisk1 --sku Premium_LRS --size 64 --lun 1 --new --caching ReadOnly # /hana/shared

# /hana/data
if [[ $hanaProdStorageUltra -eq '0' ]]; then
for i in $(eval echo "{2..$((hanaDataDisksCount+1))}") # +1 due to start 0 and 2 disks already created
do
az vm disk attach --resource-group $rgName --vm-name $vmName --name ${vmName}-datadisk${i} --sku Premium_LRS --size 1024 --lun $i --new --caching None 
done
elif [[ $hanaProdStorage -eq '1' && $hanaProdStorageUltra -eq '1' ]]; then
az vm disk attach --resource-group $rgName --vm-name $vmName --name ${vmName}-datadisk2 --sku UltraSSD_LRS --size 128 --lun 2 --new --caching None 
az disk update --resource-group $rgName --name ${vmName}-datadisk2 --set diskIopsReadWrite=7500 --set diskMbpsReadWrite=400
hanaDataDisksCount=1
fi

# /hana/log 
if [[ $hanaProdStorage -eq '1' && $hanaProdStorageUltra -eq '1' ]]; then
az vm disk attach --resource-group $rgName --vm-name $vmName --name ${vmName}-datadisk3 --sku UltraSSD_LRS --size 64 --lun 3 --new --caching None
az disk update --resource-group $rgName --name ${vmName}-datadisk3 --set diskIopsReadWrite=2000 --set diskMbpsReadWrite=250
hanaLogDisksCount=1
elif [[ $hanaProdStorage -eq '1' && $hanaProdStorageUltra -eq '0' ]]; then   # don't create log disks for cost-optimized setup, only prod-like
    for i in $(eval echo "{$((hanaDataDisksCount+2))..$((hanaDataDisksCount+hanaLogDisksCount+1))}") 
    do
    az vm disk attach --resource-group $rgName --vm-name $vmName --name ${vmName}-datadisk${i} --sku Premium_LRS --size 64 --lun $i --new --caching None --enable-write-accelerator
    done
fi

# /hana/backup
for i in $(eval echo "{$((hanaDataDisksCount+hanaLogDisksCount+2))..$((hanaDataDisksCount+hanaLogDisksCount+hanaBackupDisksCount+1))}") 
do
az vm disk attach --resource-group $rgName --vm-name $vmName --name ${vmName}-datadisk${i} --sku Premium_LRS --size 64 --lun $i --new --caching ReadOnly
done

PubIpFqdn=`az network public-ip list --resource-group $rgName|grep fqdn | grep $vmName | awk '{print $2}'|sed 's/.\{2\}$//'|cut -c2-`
# do stuff inside VM
ssh -oStrictHostKeyChecking=no ${vmAdminUser}@${PubIpFqdn} 

