#!/bin/bash

HOSTNAME=$(hostname)
LOGFILE="/tmp/gen1-system-check-${HOSTNAME}.log"

NC='\e[39m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'

function print_usage () {
    echo ""
    echo "Usage:"
    echo "Checks the OS if requirements for direct modification of VM to Azure Gen2 are fullfilled"
    echo "Script must be executed with root rights."
    echo "No parameters are necessary."
    echo "Display only, no change done."
    echo "Output is provided on screen and also logged to" $LOGFILE
    echo "Three check criteria, all three must succeed:"
    echo "Condition 1: Is boot disk of type GPT."
    echo "Condition 2: Is an EFI partition located on the boot disk."
    echo "Condition 3: Is /boot/efi added to /etc/fstab."
    echo ""
    exit 0
}

function infoLog () {
    echo -e "${GREEN}INFO:  ${NC}" "$*" | tee -a $LOGFILE
}

function warnLog () {
    echo -e "${YELLOW}WARN:  ${NC}" "$*" | tee -a $LOGFILE
}

function errLog () {
    echo -e "${RED}ERROR: ${NC}" "$*" | tee -a $LOGFILE
}

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Exiting."
    print_usage
    exit 1
fi

# log hostname
infoLog "Hostname: $HOSTNAME"

# Query Azure IMDS endpoint for VM details
infoLog "Determining Azure information."
azureVmSku=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2021-02-01&format=text")
azureVmGen=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/sku?api-version=2021-02-01&format=text")
azureVmName=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/name?api-version=2021-02-01&format=text")
azureArmId=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/resourceId?api-version=2021-02-01&format=text")
infoLog "VM Name: $azureVmName"
infoLog "VM SKU: $azureVmSku"
infoLog "VM Generation: $azureVmGen"
infoLog "VM Arm ID: $azureArmId"

[[ "$azureVmGen" == "gen2" ]] && warnLog "VM is already of Gen2 type, exiting." && exit 0

# Determine the boot device and boot partition
bootDevice=$(df /boot | tail -1 | awk '{print substr($1, 1, length($1)-1)}')
infoLog "Disk device with /boot: $bootDevice"

# Determine the type of disk (GPT, MBR, or unknown)
# diskType=$(lsblk --scsi -no NAME,PTTYPE $bootDevice | awk '{print $2}')
diskType=$(blkid $bootDevice -o value -s PTTYPE)
case "$diskType" in 
    gpt)
        infoLog "Condition 1: SUCCESS - Disk type is GPT on" $bootDevice
        check1=ok
        ;;
    msdos)
        errLog "Condition 1: ERROR - Disk type is MBR on" $bootDevice
        check1=err
        ;;
    *)
        errLog "Condition 1: ERROR - Disk type could not be determined on" $bootDevice
        check1=warn
esac

efiPartition=$(fdisk -l $bootDevice | grep EFI | awk '{printf $1}')
if [[ -n $efiPartition ]]; then
    infoLog "Condition 2: SUCCESS - EFI partition present on OS disk"
    check2=ok
else
    errLog "Condition 2: ERROR - No EFI partition detected."
    check2=err
fi

infoLog "Information on detected EFI partition (lsblk):" "\n" "$(sudo lsblk $efiPartition)"

# Check and confirm if /boot/efi is present in /etc/fstab
if grep -qs '/boot/efi' /etc/fstab; then
    infoLog "/etc/fstab entry:" "\n" "$(grep -s '/boot/efi' /etc/fstab)"
    infoLog "Condition 3: SUCCESS - /boot/efi is present in /etc/fstab"
    check3=ok
else
    errLog  "Condition 3: ERROR - /boot/efi is not present in /etc/fstab"
    check3=err
fi

# This check #4 is optional and not evaluated as success for now
grubDefault="$(grep "^GRUB_DEFAULT" /etc/default/grub | cut -d "=" -f2)"
grubEnvEntry="$(grep saved_entry /boot/grub2/grubenv | cut -d "=" -f2)"
if [[ -z $grubEnvEntry ]]; then
    case "$grubDefault" in
        [0-9]|"")
            searchEnd="$(( grubDefault +1 ))"
            grubHasEfiHint="$(grep -m $searchEnd 'menuentry ' /boot/grub2/grub.cfg -A 14 | tail -15 | grep 'hint-efi')"
            ;;
        "saved")
            warnLog "Grub default set saved, check not implemented"
            ;;
        *)
            grubHasEfiHint="$(grep -m 1 ${grubDefault} /boot/grub2/grub.cfg -A 14 | grep 'hint-efi')"
            ;;
    esac 
else
    grubHasEfiHint="$(grep "$grubEnvEntry" /boot/grub2/grub.cfg -A 14 | grep 'hint-efi')"
fi

if [[ -z "$grubHasEfiHint" ]]; then
    warnLog "Grub2 menu entry in /boot/grub2/grub.cfg does not exist or does not contain --hint-efi switch"
    check4=warn
else
    infoLog "Optional check #4: Grub2 menu item for default kernel contains --hint-efi switch"
    check4=ok
fi

# Finished checks, get helping output for troubleshooting
infoLog "#########################################################"
infoLog "Checks completed, adding some troubleshooting information"

# Display partition table on the boot device
infoLog "fdisk output for" $bootDevice "\n" "$(fdisk -l $bootDevice)"

# Display output of 'gdisk -l' on the boot device, if gdisk is installed
if command -v gdisk &> /dev/null; then
    infoLog "gdisk output fro" $bootDevice "\n" "$(gdisk -l $bootDevice)"
else
    warnLog "Gdisk is not installed, could not provide gdisk output"
fi

infoLog "###############################################################"
case "$check1$check2$check3" in
    "okokok")
        infoLog "All checks completed successfully"
        infoLog "VM can be migrated from Gen1 to Gen2 using Azure VM update API"
        ;;
    *"warn"*|*"err"*|*"")
        errLog "Some errors detected. Read full output and correct"
        errLog "NOT SAFE TO PROCEED WITH Azure VM Gen1 to Gen2 migration!"
        ;;
esac

infoLog "###############################################################"

infoLog "End of script."
echo "Log file: $LOGFILE"
