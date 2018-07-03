#!/bin/bash

###########################################################
# Setup machine for HANA
###########################################################

# setup disk layout
echo "Creating partitions and physical volumes"
sudo sh -c 'echo -e "n\n\n\n\n\nw\n" | fdisk /dev/disk/azure/scsi1/lun0'
sudo sh -c 'echo -e "n\n\n\n\n\nw\n" | fdisk /dev/disk/azure/scsi1/lun1'
sudo sh -c 'echo -e "n\n\n\n\n\nw\n" | fdisk /dev/disk/azure/scsi1/lun2'
sudo pvcreate /dev/disk/azure/scsi1/lun0-part1   
sudo pvcreate /dev/disk/azure/scsi1/lun1-part1
sudo pvcreate /dev/disk/azure/scsi1/lun2-part1

echo "Creating volume groups"
sudo vgcreate vg_hana_data /dev/disk/azure/scsi1/lun0-part1
sudo vgcreate vg_hana_log /dev/disk/azure/scsi1/lun1-part1
sudo vgcreate vg_hana_shared /dev/disk/azure/scsi1/lun2-part1

echo "Create logical volumes"
sudo lvcreate -l 100%FREE -n hana_data vg_hana_data
sudo lvcreate -l 100%FREE -n hana_log vg_hana_log
sudo lvcreate -l 100%FREE -n hana_shared vg_hana_shared
sudo mkfs.xfs /dev/vg_hana_data/hana_data
sudo mkfs.xfs /dev/vg_hana_log/hana_log
sudo mkfs.xfs /dev/vg_hana_shared/hana_shared

echo "Creating mount points"
mkdir /hana
mkdir /hana/data
mkdir /hana/log
mkdir /hana/shared

# Mount volumes
echo "Mounting volumes into fstab"
cat << EOF | sudo tee -a /etc/fstab
/dev/vg_hana_shared/hana_shared /hana/shared xfs  defaults,nofail  0  2
/dev/vg_hana_log/hana_log /hana/log xfs  defaults,nofail  0  2
/dev/vg_hana_data/hana_data /hana/data xfs  defaults,nofail  0  2
EOF
sudo mount -a
