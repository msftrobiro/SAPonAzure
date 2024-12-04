#!/bin/bash

HOSTNAME=$(hostname)

NC='\e[39m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'

function print_usage () {
    echo ""
    echo "Usage:"
    echo "No parameters or switches are necessary."
    echo "Script must be executed with root rights."
    echo "Display only, no change done."
    echo ""
    exit 0
}

function infoLog () {
    echo -e "${GREEN}INFO: ${NC}" "$*"
}

function warnLog () {
    echo -e "${YELLOW}WARN: ${NC}" "$*"
}

function errLog () {
    echo -e "${RED}ERROR:${NC}" "$*"
}

# SWAP check script
errorsFound=0

# check if swap configured
if [[ $( cat /proc/swaps | wc -l ) -gt 1 ]];
    then 
        infoLog "Swap is configured, details from /proc/swaps:" "\n" "$( cat /proc/swaps )"
        infoLog "End of swap info output."
        swapSetup=1
    else
        infoLog "No swap is configured."
        swapSetup=0
fi

# check for VM diskcontroller (not in IMDS data). nvme0n1 is boot disk and always present
diskControllerType=""
[[ -e /dev/nvme0n1 ]] && diskControllerType="nvme"
[[ -e /dev/disk/azure/root ]] && diskControllerType="scsi"

# what is the resource disk's mountpoint?
scsiResourceDisk=$( readlink -f /dev/disk/azure/resource )
nvmeResourceDisk="/dev/nvme1n1"
[[ $diskControllerType == "scsi" ]] && resourceDiskMount=$( grep $(basename $scsiResourceDisk) /proc/mounts | awk '{print $2}' )
# [[ $diskControllerType == "scsi" ]] && resourceDiskMount=$( grep $( echo $scsiResourceDisk | cut -d "/" -f3 ) /proc/mounts | awk '{print $2}' )
[[ $diskControllerType == "nvme" ]] && resourceDiskMount=$( grep $nvmeResourceDisk /proc/mounts | awk '{print $2}' )

# what's on the resource disk
if [[ -n $resourceDiskMount ]]; 
then
    infoLog "Resource disk exists with mountpoint" $resourceDiskMount "."
    resourceDiskUsage=$( sudo du -sm $resourceDiskMount | awk '{print $1}' )
    case "$resourceDiskUsage" in 
        [0-2])
            [[ $diskControllerType == "scsi" ]] && infoLog "Resource disk" ${scsiResourceDisk} "mounted at" ${resourceDiskMount} "is effectively empty." 
            [[ $diskControllerType == "nvme" ]] && infoLog "Resource disk /dev/nvme1n1 mounted at" ${resourceDiskMount} "is effectively empty." 
            ;;
        *)
            warnLog "Resource disk is not empty."
            [[ $diskControllerType == "scsi" ]] && warnLog "Resource disk" ${scsiResourceDisk} "mounted at" ${resourceDiskMount} "contains" $resourceDiskUsage "MiB of data."
            [[ $diskControllerType == "nvme" ]] && warnLog "Resource disk /dev/nvme1n1 mounted at" ${resourceDiskMount} "contains" $resourceDiskUsage "MiB of data."
            warnLog "Examine contents on resource disk " ${resourceDiskMount}.
            errorsFound=1
            ;;
    esac
else
    infoLog "Resource disk not detected."
fi

# Swap details
if [[ "$swapSetup" == 1 ]];
then
    infoLog "Checking details of active swap configuration."
    tail -n +2 /proc/swaps | awk '{if ($2 == "file") print "file "$1; else if ($2 == "partition") print "partition "$1}' | while read type swapItem;
    do
        if [[ $type == "file" ]]; then
            swapFileMount=$( stat -c %m ${swapItem} )
            if [[ ${swapFileMount} == ${resourceDiskMount} ]]; then
                warnLog "Swap file" ${swapItem} "is located on resource disk" ${resourceDiskMount}.
                errorsFound=1
            else
                infoLog "Swap file" ${swapItem} "is NOT located on resource disk" ${resourceDiskMount} ". OK"
            fi
        elif [[ $type == "partition" ]]; then
            infoLog "Swap partition" ${swapItem} "is active. This is not on resource disk. OK"
        fi
    done
else
    infoLog "No swap is configured. OK"
fi

# wrap-up
infoLog "#####################"
infoLog "End of script output:"
if [[ $errorsFound == 1 ]];
then
    errLog "Errors found. Do not proceed with VM resize to SKUs with temp-less configuration."
    warnLog "Proceeding with VM resize to VM without temporary disk will cause problems with swap configuration."
    warnLog "Do not proceed with VM resize to temp-less SKU as all contents on resource disk will be lost."
    warnLog "Do no proceed with VM resize until swap is reconfigured or contents detected on resource disk clarified."
    warnLog "See preceding error messages for details."
    exit 1
else
    infoLog "No errors found. Check for any configuration using resource disk."
    infoLog "You should be safe to proceed with VM resize."
    exit 0
fi
