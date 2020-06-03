#!/bin/bash
# Script to create HANA filesystems on Azure
# Creates production-ready setups with both premiumSSD and UltraDisk as well as cost-concious storage design for systems where single VM SLA not important along with lower performance targets
# VMs need to be created with following data disks lun design
# LUN 0 disk for /usr/sap (always just 1)
# LUN 1 disk for /hana/shared (always just 1)
# LUN 2+ disks for /hana/data (or shared hana data+log for non-prod) (3 or more, 1 for UltraDisk)
# LUNs after are disks for /hana/log (2 for premSSD, 1 for Ultradisk, 0 for non-prod lowcost) and /hana/backup 
# Any other, custom LUNs, only AFTER the above disks are handled
#
# Disk sizing from https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/hana-vm-operations-storage#solutions-with-premium-storage-and-azure-write-accelerator-for-azure-m-series-virtual-machines
# Disk sizes for prod premSSD
# /usr/sap  1x P6
# /hana/shared 1x P20 (< 1GB RAM) or 1x P30 (=> 1GB RAM)
# /hana/log  2x P20
# /hana/data  (M32ts, M32ls, M64ls) 3x P20, M64s 4x P20, (M64ms, M128s) 3x P30, M128ms 5x P30, M208s_v2 4x P30, (M208ms_v2, M416s_v2) 4x P40, M416ms_v2 8x P40
# /hana/backup (M32ts, M32ls) 1x P20, M64ls 1x P30, M64s 2x P30, M64ms 3x P30, M128s 2x P40, M128ms 4x P40, M208s_v2 3x P40, (M208ms_v2, M416s_v2) 3x P50, M416ms_v2 4x P50
#
# Disk sizes for prod ultra
# /usr/sap, /hana/shared, /hana/backup same as with premium SSD
# /hana/log (M32ts, M32ls) 256GB/250MBps/2000IOPS, (E64s_v3, M64ls, M64s, M64ms) 512GB/400MBps/2500IOPS, (M128s, M128ms) 512GB/800MBps/3000IOPS, (M208s_v2, M208ms_v2) 512GB/400MBps/2500IOPS, (M416s_v2, M416ms_v2) 512GB/800MBps/3000IOPS
# /hana/data E64s_v3 600GB/700MBps/7500, (M32ts, M32ls) 250/400/7500, M64ls 600/600/7500, M64s 1200/600/7500, M64ms 2100/600/7500, M128s 2400/1200/9000, M128ms 4800/1200/9000, M208s_v2 3500/1000/9000, M208ms_v2 7200/1000/9000, M416s_v2 7200/1500/9000, M416ms_v2 14400/1500/9000
#
# Cost-consious non-SLA storage
# os-disk 1x E6
# /usr/sap  1x E6
# /hana/shared 1x E20 (< 1GB RAM) or 1x E30 (=> 1GB RAM)
# /hana/data and /hana/log on shared VG/array (E16s_v3, E32s_v3, E64s_v3, M32ts, M32ls, M64ls, M64s, M64ms, M128s) 3x P30, M128ms 5x P30, M208s_v2 4x P30, (M208ms_v2, M416s_v2) 4x P40, M416ms_v2 8x P40
# /hana/backup E16s_v3 1x E15, (E32s_v3, M32ts, M32ls) 1x E20, (E64s_v3, M64ls) 1x E30, E64s 2x E30, (M64s, M64ms) 3x E30, M128s 2x E40, M128ms 2x E50, M208s_v2 3x E40, (M208ms_v2, M416s_v2) 4x E40, M416ms_v2 4x E50
# 
# Demo sizing - just use two resonably large disks for the expected workloads. At least E10's or P10 for both, or larger, for both Lun0 and Lun1
# App server sizing - E/P6 or larger for Lun0

display_usage () {
    echo "Usage:"
    echo "Script needs to be executed by an user which can non-interactively sudo restricted commands"
    echo "-------------------------------------------------------------------------------------------"
    echo "Parameters required:"
    echo "First parmeter specifies the VM size, using Azure's VM SKU names. Allow values are all Mv1/Mv2 and certified E series VMs"
    echo "Second parameter specifies type of storage used. Allowed values prod|costoptimized|ultra|demo|appserver"
    echo "prod - uses PremiumSSD for all disks, production ready sizing"
    echo "costoptimized - uses joint HANA data+log volume group, not production ready and no single-VM SLA"
    echo "ultra - uses UltraDisk for HANA data and log drives, premiumSSD for other disks. Production ready sizing"
    echo "demo - only for demo purposes, minimal storage setup of just two disks, 1st data disk for data/log and 2nd disk for all else"
    echo "appserver - for SAP ASCS/app server. Expects just one data disk and created /usr/sap, /sapmnt mounts"
    echo "---------------------------------------------"
    echo "Examples: "
    echo "sap_cre_filesystems.sh Standard_M32ts prod"
    echo "sap_cre_filesystems.sh Standard_M64s costoptimized"
    echo "sap_cre_filesystems.sh Standard_M208s_v2 ultra"
}

create_vglv_common () {
    # /usr/sap and /hana/shared first
    sudo vgcreate  vg_usr_sap /dev/disk/azure/scsi1/lun0
    sudo lvcreate -n lv_usr_sap -l +100%VG vg_usr_sap
    sudo vgcreate  vg_hana_shared /dev/disk/azure/scsi1/lun1
    sudo lvcreate -n lv_hana_shared -l +100%VG vg_hana_shared
}
create_vglv_prod_premssd () {
    hanaLogDisksCount=2
    hanaDataDisksTotalCount=$((hanaDataDisksCount+hanaLogDisksCount+hanaBackupDisksCount+2)) # +2 for shared+usrsap
    for i in $(eval echo "{0..$((hanaDataDisksTotalCount-1))}") # -1 since we start at 0
    do sudo pvcreate /dev/disk/azure/scsi1/lun${i}
    done

    create_vglv_common

    # /hana/data
    vgDisks=""
    while read num; do vgDisks+="/dev/disk/azure/scsi1/lun"${num}" "; done < <(seq 2 $((hanaDataDisksCount+1))) # start with 0, increase by 2 is thus +1
    sudo vgcreate  vg_hana_data $vgDisks
    sudo lvcreate -n lv_hana_data -l +100%VG --stripesize 256 --stripes $hanaDataDisksCount vg_hana_data

    # /hana/log 
    vgDisks=""
    while read num; do vgDisks+="/dev/disk/azure/scsi1/lun"${num}" "; done < <(seq $((hanaDataDisksCount+2)) $((hanaLogDisksCount+hanaDataDisksCount+1)))
    sudo vgcreate  vg_hana_log $vgDisks
    sudo lvcreate -n lv_hana_log -l +100%VG --stripesize 32 --stripes $hanaLogDisksCount vg_hana_log

    # /hana/backup
    vgDisks=""
    while read num; do vgDisks+="/dev/disk/azure/scsi1/lun"${num}" "; done < <(seq $((hanaDataDisksCount+hanaLogDisksCount+2)) $((hanaLogDisksCount+hanaDataDisksCount+hanaBackupDisksCount+1)))
    sudo vgcreate  vg_hana_backup $vgDisks
    sudo lvcreate -n lv_hana_backup -l +100%VG --stripesize 256 --stripes $hanaBackupDisksCount vg_hana_backup
}

create_vglv_nonprod_premssd () {
    hanaLogDisksCount=0
    hanaDataDisksTotalCount=$((hanaDataDisksCount+hanaLogDisksCount+hanaBackupDisksCount+2)) # +2 for shared+usrsap
    for i in $(eval echo "{0..$((hanaDataDisksTotalCount-1))}") # -1 since we start at 0
    do sudo pvcreate /dev/disk/azure/scsi1/lun${i}
    done

    create_vglv_common

    # /hana/data and /hana/log on one VG
    vgDisks=""
    while read num; do vgDisks+="/dev/disk/azure/scsi1/lun"${num}" "; done < <(seq 2 $((hanaDataDisksCount+hanaLogDisksCount+1))) # start with 0, increase by 2 is thus +1
    sudo vgcreate  vg_hana_datalog $vgDisks
    sudo lvcreate -n lv_hana_log -L 1T --stripesize 32 --stripes $hanaDataDisksCount vg_hana_datalog
    sudo lvcreate -n lv_hana_data -l +100%FREE --stripesize 256 --stripes $hanaDataDisksCount vg_hana_datalog

    # /hana/backup
    vgDisks=""
    while read num; do vgDisks+="/dev/disk/azure/scsi1/lun"${num}" "; done < <(seq $((hanaDataDisksCount+hanaLogDisksCount+2)) $((hanaLogDisksCount+hanaDataDisksCount+hanaBackupDisksCount+1)))
    sudo vgcreate  vg_hana_backup $vgDisks
    sudo lvcreate -n lv_hana_backup -l +100%VG --stripesize 256 --stripes $hanaBackupDisksCount vg_hana_backup
}

create_vglv_prod_ultra () {
    hanaDataDisksCount=1
    hanaLogDisksCount=1
    hanaDataDisksTotalCount=$((hanaDataDisksCount+hanaLogDisksCount+hanaBackupDisksCount+2)) # +2 for shared+usrsap
    for i in $(eval echo "{0..$((hanaDataDisksTotalCount-1))}") # -1 since we start at 0
    do sudo pvcreate /dev/disk/azure/scsi1/lun${i}
    done

    create_vglv_common

    # /hana/data
    sudo vgcreate  vg_hana_data /dev/disk/azure/scsi1/lun2
    sudo lvcreate -n lv_hana_data -l +100%VG vg_hana_data
    # /hana/log 
    sudo vgcreate  vg_hana_log /dev/disk/azure/scsi1/lun3
    sudo lvcreate -n lv_hana_log -l +100%VG vg_hana_log
    # /hana/backup
    vgDisks=""
    while read num; do vgDisks+="/dev/disk/azure/scsi1/lun"${num}" "; done < <(seq $((hanaDataDisksCount+hanaLogDisksCount+2)) $((hanaLogDisksCount+hanaDataDisksCount+hanaBackupDisksCount+1)))
    sudo vgcreate  vg_hana_backup $vgDisks
    sudo lvcreate -n lv_hana_backup -l +100%VG --stripesize 256 --stripes $hanaBackupDisksCount vg_hana_backup
}

format_and_mount () {
    if [[ $hanaStorageCostConcious == '1' ]]; then
    sudo mkfs.xfs /dev/mapper/vg_hana_datalog-lv_hana_data
    sudo mkfs.xfs /dev/mapper/vg_hana_datalog-lv_hana_log
    else
    sudo mkfs.xfs /dev/mapper/vg_hana_data-lv_hana_data
    sudo mkfs.xfs /dev/mapper/vg_hana_log-lv_hana_log
    fi
    sudo mkfs.xfs /dev/mapper/vg_hana_shared-lv_hana_shared
    sudo mkfs.xfs /dev/mapper/vg_hana_backup-lv_hana_backup
    sudo mkfs.xfs /dev/mapper/vg_usr_sap-lv_usr_sap

    sudo mkdir -p /hana/data /hana/log /hana/shared /hana/backup /usr/sap
    if [[ $hanaStorageCostConcious == '1' ]]; then
    echo '/dev/mapper/vg_hana_datalog-lv_hana_data /hana/data   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    echo '/dev/mapper/vg_hana_datalog-lv_hana_log /hana/log   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    else
    echo '/dev/mapper/vg_hana_data-lv_hana_data /hana/data   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    echo '/dev/mapper/vg_hana_log-lv_hana_log /hana/log   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    fi
    echo '/dev/mapper/vg_hana_shared-lv_hana_shared /hana/shared   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    echo '/dev/mapper/vg_hana_backup-lv_hana_backup /hana/backup   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    echo '/dev/mapper/vg_usr_sap-lv_usr_sap /usr/sap   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    sudo mount -a
}

error_wrong_vm_size () {
    echo "ERROR: Unrecognized VM type entered, see usage information"
    echo "Case sensitivity is not important, but use correct and full VM name, see examples below"
    echo "---------------------------------------------------------------------------------------"
    display_usage
    exit 3
}

error_wrong_storage_type () {
    echo "ERROR: Wrong value for storage type specified"
    echo "Allowed values are prod|costoptimized|ultra"
    echo "-------------------------------------------"
    display_usage
    exit 3
}

create_vglv_format_demo () {
    sudo pvcreate /dev/disk/azure/scsi1/lun[01]
    sudo vgcreate  vg_hana_datalog /dev/disk/azure/scsi1/lun0
    sudo lvcreate -n lv_hana_data -l +70%VG vg_hana_datalog
    sudo lvcreate -n lv_hana_log -l +100%FREE vg_hana_datalog
    sudo vgcreate  vg_hana_other /dev/disk/azure/scsi1/lun1
    sudo lvcreate -n lv_usr_sap -l +10%VG vg_hana_other
    sudo lvcreate -n lv_hana_shared -l +30%VG vg_hana_other
    sudo lvcreate -n lv_hana_backup -l +100%FREE vg_hana_other
    sudo mkfs.xfs /dev/mapper/vg_hana_datalog-lv_hana_data
    sudo mkfs.xfs /dev/mapper/vg_hana_datalog-lv_hana_log
    sudo mkfs.xfs /dev/mapper/vg_hana_other-lv_hana_shared
    sudo mkfs.xfs /dev/mapper/vg_hana_other-lv_hana_backup
    sudo mkfs.xfs /dev/mapper/vg_hana_other-lv_usr_sap

    sudo mkdir -p /hana/data /hana/log /hana/shared /hana/backup /usr/sap
    echo '/dev/mapper/vg_hana_datalog-lv_hana_data /hana/data   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    echo '/dev/mapper/vg_hana_datalog-lv_hana_log /hana/log   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    echo '/dev/mapper/vg_hana_other-lv_hana_shared /hana/shared   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    echo '/dev/mapper/vg_hana_other-lv_hana_backup /hana/backup   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    echo '/dev/mapper/vg_hana_other-lv_usr_sap /usr/sap   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    sudo mount -a
}

create_vglv_format_appserver () {
    sudo pvcreate /dev/disk/azure/scsi1/lun0
    sudo vgcreate  vg_usr_sap /dev/disk/azure/scsi1/lun0
    sudo lvcreate -n lv_usr_sap -l +50%VG vg_usr_sap
    sudo lvcreate -n lv_sapmnt -l +50%FREE vg_usr_sap
    sudo mkfs.xfs /dev/mapper/vg_usr_sap-lv_usr_sap
    sudo mkfs.xfs /dev/mapper/vg_usr_sap-lv_sapmnt

    sudo mkdir -p /usr/sap /sapmnt
    echo '/dev/mapper/vg_usr_sap-lv_usr_sap /usr/sap   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    echo '/dev/mapper/vg_usr_sap-lv_sapmnt /sapmnt   xfs      defaults,nofail,nobarrier      0 2' | sudo tee -a /etc/fstab
    sudo mount -a
}


# end of function declaration, actual script execution
if [[ $1 == "-usage" || $1 == "--usage" ||  $1 == "-h"  ||  $1 == "-help" ||  $1 == "-?"  || $1 == "--help" ]]
    then
        display_usage
        exit 0
fi

# are two parameters provided?
if [[ $# -lt 2 ]]
then
    display_usage
    exit 1
fi

vmSize=`echo "$1" | awk '{print tolower($0)}'`
storageType=`echo "$2" | awk '{print tolower($0)}'`

# check for lock file to prevent accidental re-runs of script. If doesn't exist, place one
lockFile=/tmp/sap_cre_filesystem.lock
if [[ -f $lockFile ]]; then
    echo "-------------------------------------------------------------------------------------------------"
    echo "ERROR: Lockfile "${lockFile}" exists, this script was already executed previously."
    echo "Check if safe to re-run and remove lock file."
    echo "-------------------------------------------------------------------------------------------------"
    exit 3
fi
date +%Y%h%d-%H:%M:%S > $lockFile
echo "Lock file created during execution of sap_cre_filesystems.sh" >> $lockFile
echo "Check if physical/logical volumes and volume groups, filesystems and fstab entries are created correctly." >> $lockFile

if [ $storagetype == 'demo' ]; then 
    create_vglv_format_demo
    echo "### DEBUG exiting script with 0, filesystems for "${storagetype}" created."
    exit 0
fi

if [ $storagetype == 'appserver' ]; then 
    create_vglv_format_appserver
    echo "### DEBUG exiting script with 0, filesystems for "${storagetype}" created."
    exit 0
fi

if [ $storageType == 'ultra' ]; then 
case $vmSize in 
'standard_m8ms')        hanaBackupDisksCount=1;;
'standard_m16ms')       hanaBackupDisksCount=1;;
'standard_m32ts')       hanaBackupDisksCount=1;;
'standard_m32ls')       hanaBackupDisksCount=1;;
'standard_m32ms')       hanaBackupDisksCount=1;;
'standard_m64ls')       hanaBackupDisksCount=1;;
'standard_m64s')        hanaBackupDisksCount=2;;
'standard_m64ms')       hanaBackupDisksCount=3;;
'standard_m128s')       hanaBackupDisksCount=3;;
'standard_m128ms')      hanaBackupDisksCount=4;;
'standard_m208s_v2')    hanaBackupDisksCount=3;;
'standard_m208ms_v2')   hanaBackupDisksCount=3;;
'standard_m416s_v2')    hanaBackupDisksCount=3;;
'standard_m416ms_v2')   hanaBackupDisksCount=4;;
*)   error_wrong_vm_size;;
esac
create_vglv_prod_ultra
format_and_mount
echo "### DEBUG exiting with 0"
exit 0
fi

if [ $storageType == 'prod' ]; then 
case $vmSize in 
'standard_m8ms')        hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m16ms')       hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m32ts')       hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m32ls')       hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m32ms')       hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m64ls')       hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m64s')        hanaDataDisksCount=4; hanaBackupDisksCount=2;;
'standard_m64ms')       hanaDataDisksCount=3; hanaBackupDisksCount=3;;
'standard_m128s')       hanaDataDisksCount=5; hanaBackupDisksCount=3;;
'standard_m128ms')      hanaDataDisksCount=5; hanaBackupDisksCount=4;;
'standard_m208s_v2')    hanaDataDisksCount=4; hanaBackupDisksCount=3;;
'standard_m208ms_v2')   hanaDataDisksCount=4; hanaBackupDisksCount=3;;
'standard_m416s_v2')    hanaDataDisksCount=4; hanaBackupDisksCount=3;;
'standard_m416ms_v2')   hanaDataDisksCount=8; hanaBackupDisksCount=4;;
*)
    error_wrong_vm_size
;;
esac
create_vglv_prod_premssd
format_and_mount
echo "### DEBUG exiting with 0"
exit 0
fi

if [ $storageType == 'costoptimized' ]; then 
case $vmSize in 
'standard_m8ms')        hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m16ms')       hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m32ts')       hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m32ls')       hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m32ms')       hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m64ls')       hanaDataDisksCount=3; hanaBackupDisksCount=1;;
'standard_m64s')        hanaDataDisksCount=3; hanaBackupDisksCount=2;;
'standard_m64ms')       hanaDataDisksCount=3; hanaBackupDisksCount=3;;
'standard_m128s')       hanaDataDisksCount=3; hanaBackupDisksCount=2;;
'standard_m128ms')      hanaDataDisksCount=5; hanaBackupDisksCount=2;;
'standard_m208s_v2')    hanaDataDisksCount=4; hanaBackupDisksCount=3;;
'standard_m208ms_v2')   hanaDataDisksCount=4; hanaBackupDisksCount=4;;
'standard_m416s_v2')    hanaDataDisksCount=4; hanaBackupDisksCount=4;;
'standard_m416ms_v2')   hanaDataDisksCount=8; hanaBackupDisksCount=4;;
*)
    error_wrong_vm_size
;;
esac
create_vglv_nonprod_premssd
hanaStorageCostConcious=1
format_and_mount
echo "### DEBUG exiting with 0"
exit 0
else 
    error_wrong_storage_type
fi



