#!/bin/bash

###########################################################
# Setup machine for HANA
###########################################################

# setup disk layout
echo "Creating physical volumes"
sudo pvcreate /dev/disk/azure/scsi1/lun0   
sudo pvcreate /dev/disk/azure/scsi1/lun1
sudo pvcreate /dev/disk/azure/scsi1/lun2

echo "Creating volume groups"
sudo vgcreate vg_hana_data_PV1 /dev/disk/azure/scsi1/lun0
sudo vgcreate vg_hana_log_PV1 /dev/disk/azure/scsi1/lun1
sudo vgcreate vg_hana_shared_PV1 /dev/disk/azure/scsi1/lun2

echo "Creating logical volumes"
sudo lvcreate -l 100%FREE -n hana_data vg_hana_data_PV1
sudo lvcreate -l 100%FREE -n hana_log vg_hana_log_PV1
sudo lvcreate -l 100%FREE -n hana_shared vg_hana_shared_PV1

echo "Initializing file systems"
sudo mkfs.xfs /dev/vg_hana_data_PV1/hana_data
sudo mkfs.xfs /dev/vg_hana_log_PV1/hana_log
sudo mkfs.xfs /dev/vg_hana_shared_PV1/hana_shared

echo "Creating mount points"
mkdir -p /hana/data/PV1
mkdir -p /hana/log/PV1
mkdir -p /hana/shared/PV1

# Mount volumes
echo "Mounting volumes into fstab"
cat << EOF | sudo tee -a /etc/fstab
/dev/vg_hana_shared_PV1/hana_shared /hana/shared/PV1 xfs  defaults,nofail  0  2
/dev/vg_hana_log_PV1/hana_log /hana/log/PV1 xfs  defaults,nofail  0  2
/dev/vg_hana_data_PV1/hana_data /hana/data/PV1 xfs  defaults,nofail  0  2
EOF
sudo mount -a
sudo zypper --non-interactive up
