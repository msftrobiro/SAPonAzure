#!/bin/bash
# execute on azure cloud shell, ideally. WSL, linux in windows, would in current version be much slower

function display_usage() {
    echo "### -------------------------------------------- ###"  >&2
    echo "This script requires upto three parameters"  >&2
    echo "First parameter the scope are we searching in - VM|RG|SUB - VM or Resource Group or Subscription"  >&2
    echo "Second parameter is dependant on first:"  >&2
    echo "For VM enter the VM name"  >&2
    echo "For RG enter the resource group name, in your currently active subscription"  >&2
    echo "For SUB enter the subscription id"  >&2
    echo "Third parameter only for scope of VM - provide the resource group name"  >&2
    echo "Examples: <script> VM vm-db01 my-super-rg"  >&2
    echo "          <script> RG my-super-rg"  >&2
    echo "### -------------------------------------------- ###"  >&2
}

function get_vm_azure_info() {
    VMINFO=$(az vm get-instance-view --name ${VMNAME} --resource-group ${RGNAME})
    VMSIZE=$(echo $VMINFO | jq -r '.hardwareProfile.vmSize')
    VMSTATE=$(echo $VMINFO| jq -r '.instanceView.statuses[1].displayStatus')
    AVZONE=$(echo $VMINFO| jq -r '.zones[0]')
    PPG=$(echo $VMINFO| jq -r '.proximityPlacementGroup.id'|awk '{print $NF}' FS=/)
    NUMNICS=$(az vm nic list --vm-name ${VMNAME} --resource-group ${RGNAME} --query "[].id" -o tsv| wc -l)
    ACCELNET=$(az vm nic show --vm-name ${VMNAME} --resource-group ${RGNAME} --nic $(az vm nic list --vm-name ${VMNAME} --resource-group ${RGNAME} --query "[0].id" -o tsv) |jq -r '.enableAcceleratedNetworking')
    OSDISKSKU=$(az disk show --id $(echo $VMINFO | jq -r '.storageProfile.osDisk.managedDisk.id') | jq -r '.sku.name')
    OSDISKSIZE=$(az disk show --id $(echo $VMINFO | jq -r '.storageProfile.osDisk.managedDisk.id') | jq -r '.diskSizeGb')
    # 0 based NUMDATADISKS
    NUMDATADISKS=$(echo $VMINFO | jq -r '[.storageProfile.dataDisks[].lun] | max')
    DATADISKIDS=$(echo $VMINFO | jq -r '.storageProfile.dataDisks[].managedDisk.id')
    for i in $NUMDATADISKS;
    do 
### TBC

    echo ${OSDISKSKU}" "${OSDISKSIZE}" "${NUMDATADISKS}" "${DATADISKIDS}

    if [[ -z $AVZONE ]]; then AVZONE="No"; fi

    echo ${VMNAME}" "${RGNAME}" "${VMSIZE}" "${AVZONE}" "${PPG}" "${NUMNICS}" "${ACCELNET}" "${OSDISK}" "${NUMDATADISKS}

    # time to get details from the VM
    if [[ $VMSTATE != "VM running" ]]; then echo "### VM is not running, status:"${VMSTATE}" ###"; else look_into_the_vm; fi

}

function look_into_the_vm() {
    az vm run-command invoke --resource-group $RGNAME --name $VMNAME --command-id RunShellScript --scripts "pvdisplay"
    az vm run-command invoke --resource-group rg-weu-sap-bw-prod --name vm-multi-nic-wa --command-id RunShellScript --scripts "pvdisplay"
    az vm run-command invoke --resource-group rg-eun-sap-shq --name vm-eun-shqdb01 --command-id RunShellScript --scripts "pvdisplay"
}

# --------- END OF FUNCTION DEFINITION ---------


# make sure azure cli is logged in
if az account show | grep -m 1 "login"; then
    echo "###-------------------------------------###"  >&2
    echo "Need to authenticate you with az cli"  >&2
    echo "Follow prompt to authenticate in browser window with device code displayed"  >&2
    az login
fi

if ! [ -x "$(command -v jq)" ]; then
  echo "Error: jq package is not installed. https://stedolan.github.io/jq/download/" >&2
  exit 1
fi

if [[ $DEBUG == "1" ]]; then set -x; fi

SCOPETYPE=`echo $1 | awk '{print toupper($0)}'`
SCOPEVALUE=`echo $2 | awk '{print toupper($0)}'`
RGNAME=`echo $3 | awk '{print toupper($0)}'`

case $SCOPETYPE in
    VM)
        if [[ -z $RGNAME ]]; then
            display_usage
            printf '%s\n'; echo "Missing resource group name for specified VM"  >&2
            exit 1
        fi
        if ! az group show --name $RGNAME > /dev/null 2>&1; then
            echo "Specified resource group does not exist in current subscription, check entered value "${SCOPERG}  >&2
            echo "Change current subscription if needed with \"az account set --subscription <subscription_name/id\""  >&2
            exit 1
        fi
        VMNAME=$SCOPEVALUE
        get_vm_azure_info
        echo "VM branch end reached"  >&2
        ;;
    RG) 
        echo "RG ok"  >&2
        ;;
    SUB)
        echo "SUB ok"  >&2
        ;;
    *)
        display_usage
        printf '%s\n'; echo "Wrong scope type specified - allowed values are VM|RG|SUB only"  >&2
        exit 1
        ;;
esac

echo "end of script reached"  >&2
