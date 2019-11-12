#!/bin/bash
# continue on your jumpbox, NOT in your shell/cloud shell
# ideally, 1_create_jumpbox.sh should have finished without problems
# this script assumes everything is executed on the newly created jumpbox
# version 0.3  
# last major changes: added ERS install but not yet working

source parameters.txt
LOGFILE=/tmp/2_create_SAP_infra.log
if [[ -z $AZLOCTLA ]]; 
    then RGNAME=rg-${RESOURCEGROUP}
    else AZLOCTLA=${AZLOCTLA}-; RGNAME=rg-${AZLOCTLA}${RESOURCEGROUP}
fi
starttime=`date +%s`
echo "###-------------------------------------###"
echo "Need to authenticate you with az cli on this jumpbox"
echo "Follow prompt to authenticate in browser window with device code displayed"
az login

if [ $? -ne 0 ];
    then
        echo "Some error occured with az login, check display"
        exit 1
fi

echo "###-------------------------------------###"
echo "Azure cli logged on successfully"
echo "###-------------------------------------###"


az account set --subscription $AZSUB >>$LOGFILE 2>&1
wget "https://saeunsapsoft.blob.core.windows.net/sapsoft/linux_tools/sockperf?sv=2018-03-28&ss=bfqt&srt=sco&sp=r&se=2023-10-04T19:12:30Z&st=2019-10-04T11:12:30Z&spr=https&sig=l1kQEWAWMYlqm08BHzHOIBykTdrL6DlpzRBYhMkPSXw%3D" -O ~/sockperf --quiet >>$LOGFILE 2>&1 && sudo chmod ugo+x ~/sockperf 
wget "https://saeunsapsoft.blob.core.windows.net/sapsoft/linux_tools/DLManager.jar?sv=2018-03-28&ss=bfqt&srt=sco&sp=r&se=2023-10-04T19:12:30Z&st=2019-10-04T11:12:30Z&spr=https&sig=l1kQEWAWMYlqm08BHzHOIBykTdrL6DlpzRBYhMkPSXw%3D" -O ~/DLManager.jar --quiet >>$LOGFILE 2>&1


create_app_vm () {
    printf '%s\n'
    echo "###-------------------------------------###"
    echo Creating VM $VMNAME in RG $RGNAME
    az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${APPLSUBNET}.${ip} --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-appl --zone $i --ppg ppg-${AZLOCTLA}${SIDLOWER}-zone${i} >>$LOGFILE 2>&1   
    az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new  --lun 0 --sku StandardSSD_LRS --size 65 >>$LOGFILE 2>&1
}

create_hana_vm () {
    printf '%s\n'
    echo "###-------------------------------------###"
    echo Creating VM $VMNAME in RG $RGNAME
    az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${DBSUBNET}.${ip} --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-db --zone $i --ppg ppg-${AZLOCTLA}${SIDLOWER}-zone${i} >>$LOGFILE 2>&1   
    az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --lun 1 --sku StandardSSD_LRS --size 65 >>$LOGFILE 2>&1
    az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk2 --new --lun 2 --sku Premium_LRS --size 127 >>$LOGFILE 2>&1
    az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk3 --new --lun 3 --sku Premium_LRS --size 127 >>$LOGFILE 2>&1
    az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk4 --new --lun 4 --sku Premium_LRS --size 127 >>$LOGFILE 2>&1  
    az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk5 --new --lun 5 --sku StandardSSD_LRS --size 127 >>$LOGFILE 2>&1
    az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk6 --new --lun 6 --sku StandardSSD_LRS --size 127 >>$LOGFILE 2>&1
}

create_ppg () {
    az ppg create --resource-group $RGNAME --name ppg-${AZLOCTLA}${SIDLOWER}-zone1 --location $AZLOC --type Standard >>$LOGFILE 2>&1 
    az ppg create --resource-group $RGNAME --name ppg-${AZLOCTLA}${SIDLOWER}-zone2 --location $AZLOC --type Standard >>$LOGFILE 2>&1  
}

fs_create_on_all_sap_servers () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/vm_ips.txt ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
sudo bash -c "cat /tmp/vm_ips.txt >> /etc/hosts"
sudo pvcreate /dev/disk/azure/scsi1/lun0
sudo vgcreate vg_SAP /dev/disk/azure/scsi1/lun0
sudo lvcreate -n lv_SAP_usrsap -l 90%VG vg_SAP
sudo lvcreate -n lv_SAP_sapmnt -l 5%VG vg_SAP
sudo su -
echo 'UUID='\`blkid -s UUID -o value /dev/mapper/vg_SAP-lv_SAP_sapmnt\`' /sapmnt   xfs      defaults      0 0' >> /etc/fstab
echo 'UUID='\`blkid -s UUID -o value /dev/mapper/vg_SAP-lv_SAP_usrsap\`' /usr/sap   xfs      defaults      0 0' >> /etc/fstab
mkfs.xfs /dev/mapper/vg_SAP-lv_SAP_usrsap
mkfs.xfs /dev/mapper/vg_SAP-lv_SAP_sapmnt
mkdir /usr/sap /sapmnt
mount -a
sed -i 's/ResourceDisk.Format=n/ResourceDisk.Format=y/g' /etc/waagent.conf
sed -i 's/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g' /etc/waagent.conf
sed -i 's/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=20480/g' /etc/waagent.conf
systemctl restart waagent
swapon -s
exit
EOF
}

fs_create_on_db_servers () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/vm_ips.txt ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
sudo pvcreate /dev/disk/azure/scsi1/lun1
sudo pvcreate /dev/disk/azure/scsi1/lun2
sudo pvcreate /dev/disk/azure/scsi1/lun3
sudo pvcreate /dev/disk/azure/scsi1/lun4
sudo pvcreate /dev/disk/azure/scsi1/lun5
sudo vgcreate vg_HANA /dev/disk/azure/scsi1/lun[123]
sudo lvcreate -n lv_HANA_log -l 30%VG --stripesize 128 --stripes 3 vg_HANA
sudo lvcreate -n lv_HANA_data -l +60%VG --stripesize 128 --stripes 3 vg_HANA
sudo vgcreate vg_HANA_shared /dev/disk/azure/scsi1/lun4
sudo vgcreate vg_HANA_backup /dev/disk/azure/scsi1/lun5
sudo lvcreate -n lv_HANA_shared -l 90%VG vg_HANA_shared
sudo lvcreate -n lv_HANA_backup -l 90%VG vg_HANA_backup
sudo su -
echo 'UUID='\`blkid -s UUID -o value /dev/mapper/vg_HANA-lv_HANA_log\`' /hana/log   xfs      defaults      0 0' >> /etc/fstab
echo 'UUID='\`blkid -s UUID -o value /dev/mapper/vg_HANA-lv_HANA_data\`' /hana/data   xfs      defaults      0 0' >> /etc/fstab
echo 'UUID='\`blkid -s UUID -o value /dev/mapper/vg_HANA_shared-lv_HANA_shared\`' /hana/shared   xfs      defaults      0 0' >> /etc/fstab
echo 'UUID='\`blkid -s UUID -o value /dev/mapper/vg_HANA_backup-lv_HANA_backup\`' /hana/backup   xfs      defaults      0 0' >> /etc/fstab
mkfs.xfs /dev/mapper/vg_HANA-lv_HANA_log
mkfs.xfs /dev/mapper/vg_HANA-lv_HANA_data
mkfs.xfs /dev/mapper/vg_HANA_shared-lv_HANA_shared
mkfs.xfs /dev/mapper/vg_HANA_backup-lv_HANA_backup
mkdir -p /hana/data /hana/log /hana/shared /hana/backup
mount -a
zypper install -y saptune sapconf unrar
zypper in -t pattern -y sap-hana
saptune solution apply HANA
saptune daemon start
EOF
}

download_url () {
if [ -z "$STORACCURL" ]; then
    sasToken=$(az storage blob generate-sas --account-name ${STORACC} --account-key $storageAccountKey --container-name ${STORCONTAINER} --name $1 --permissions r --expiry $expiry --output tsv)
    shortURL=$(az storage blob url --account-name ${STORACC} --container-name ${STORCONTAINER} --name $1 --output tsv)
    fullURL=$shortURL?$sasToken
else
    fullURL=${STORACCURL}${1}${STORSAS}
fi
echo $fullURL
}

create_installfile_ascs () {
echo "sudo mkdir /usr/sap/download && sudo chmod 777 /usr/sap/download && cd /usr/sap/download" > /tmp/${SIDLOWER}_install_ascs.sh
echo "mkdir installation" >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget "'`download_url sapcar_linux`'" -O /usr/sap/download/sapcar --quiet && sudo chmod ugo+x /usr/sap/download/sapcar'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget "'`download_url SWPM.SAR`'" -O /usr/sap/download/SWPM.sar --quiet'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget "'`download_url SAPEXE.SAR`'" -O /usr/sap/download/installation/SAPEXE.SAR --quiet'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget "'`download_url DW.SAR`'" -O /usr/sap/download/installation/DW.SAR --quiet'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget "'`download_url SAPHOSTAGENT.SAR`'" -O /usr/sap/download/installation/SAPHOSTAGENT.SAR --quiet'  >> /tmp/${SIDLOWER}_install_ascs.sh
# echo 'wget "'`download_url ascs_instkey.pkey`'" -O /usr/sap/download/instkey.pkey --quiet'  >> /tmp/${SIDLOWER}_install_ascs.sh

# ascs ini file modifications
wget https://github.com/msftrobiro/SAPonAzure/raw/master/temp_sap_systems/install_files/ascs_install_ini.params --quiet -O /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MASTERPW}" /tmp/${SIDLOWER}_ascs_install_ini.params 
sed -i  "/NW_GetSidNoProfiles.sid/ c\NW_GetSidNoProfiles.sid = ${SAPSID}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_SCS_Instance.instanceNumber/ c\NW_SCS_Instance.instanceNumber = ${ASCSNO}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_SCS_Instance.scsVirtualHostname / c\NW_SCS_Instance.scsVirtualHostname = ${VMNAME}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_webdispatcher_Instance.scenarioSize/ c\NW_webdispatcher_Instance.scenarioSize = 500" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_webdispatcher_Instance.wdHTTPPort/ c\NW_webdispatcher_Instance.wdHTTPPort = 80${ASCSNO}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_webdispatcher_Instance.wdHTTPSPort/ c\NW_webdispatcher_Instance.wdHTTPSPort = 443${ASCSNO}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/nwUsers.sapadmUID/ c\nwUsers.sapadmUID = 1001" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = 200" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = 1010" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/nwUsers.sidadmPassword/ c\nwUsers.sidadmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_ascs_install_ini.params
echo 'sudo su -' >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'cd /usr/sap/download && mkdir SWPM && mv SWPM.sar SWPM && cd SWPM && ../sapcar -xf SWPM.sar'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'export SAPINST_INPUT_PARAMETERS_URL=/tmp/'${SIDLOWER}'_ascs_install_ini.params' >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'export SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_ASCS:NW752.HDB.HA' >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'export SAPINST_SKIP_DIALOGS=true' >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'export SAPINST_START_GUISERVER=false' >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'cd /usr/sap/download/SWPM && ./sapinst' >> /tmp/${SIDLOWER}_install_ascs.sh
}

execute_install_ascs () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/${SIDLOWER}_ascs_install_ini.params ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/${SIDLOWER}_install_ascs.sh`
sudo su - ${SIDLOWER}adm  -c "sapcontrol -nr ${ASCSNO} -function GetProcessList"
EOF
}

setup_nfs_server () { 
APPLSUBNET=`echo ${SAPIP}|sed 's/.\{5\}$//'`
echo 'sudo chown '${SIDLOWER}'adm:sapsys /usr/sap' > /tmp/setup_nfs_server
echo 'sudo su - '${SIDLOWER}'adm -c "mkdir /usr/sap/trans"' >> /tmp/setup_nfs_server
echo 'sudo sh -c "echo  /sapmnt/'${SAPSID}'    '${APPLSUBNET}'.0/24\(rw,no_root_squash\) >> /etc/exports"' >> /tmp/setup_nfs_server
echo 'sudo sh -c "echo  /usr/sap/trans    '${APPLSUBNET}'.0/24\(rw,no_root_squash\) >> /etc/exports"' >> /tmp/setup_nfs_server
echo 'sudo systemctl enable nfsserver' >> /tmp/setup_nfs_server
echo 'sudo systemctl start nfsserver' >> /tmp/setup_nfs_server
echo 'sudo su - '${SIDLOWER}'adm sh -c "echo dbs/hdb/schema = SAPSR3 >> /sapmnt/'${SAPSID}'/profile/DEFAULT.PFL"' >> /tmp/setup_nfs_server

ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/setup_nfs_server`
exit
EOF
}

mount_nfs_export () {
    echo 'sudo sh -c "echo '${SIDLOWER}ascs01':/sapmnt/'${SAPSID}'    /sapmnt/'${SAPSID}'  nfs  defaults 0 0 >> /etc/fstab"' > /tmp/mount_nfs_export
    echo 'sudo sh -c "echo '${SIDLOWER}ascs01':/usr/sap/trans    /usr/sap/trans  nfs  defaults 0 0 >> /etc/fstab"' >> /tmp/mount_nfs_export
    ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
sudo mkdir /usr/sap/trans /sapmnt/${SAPSID}
`cat /tmp/mount_nfs_export`
sudo mount -a -t nfs
EOF
}

create_installfile_ers () {
echo "sudo mkdir /usr/sap/download && sudo chmod 777 /usr/sap/download && cd /usr/sap/download" > /tmp/${SIDLOWER}_install_ers.sh
echo "mkdir installation" >> /tmp/${SIDLOWER}_install_ers.sh
echo 'wget "'`download_url sapcar_linux`'" -O /usr/sap/download/sapcar && sudo chmod ugo+x /usr/sap/download/sapcar'  >> /tmp/${SIDLOWER}_install_ers.sh
echo 'wget "'`download_url SWPM.SAR`'" -O /usr/sap/download/SWPM.sar'  >> /tmp/${SIDLOWER}_install_ers.sh
echo 'wget "'`download_url SAPEXE.SAR`'" -O /usr/sap/download/installation/SAPEXE.SAR'  >> /tmp/${SIDLOWER}_install_ers.sh
echo 'wget "'`download_url DW.SAR`'" -O /usr/sap/download/installation/DW.SAR'  >> /tmp/${SIDLOWER}_install_ers.sh
echo 'wget "'`download_url SAPHOSTAGENT.SAR`'" -O /usr/sap/download/installation/SAPHOSTAGENT.SAR'  >> /tmp/${SIDLOWER}_install_ers.sh
# ers ini file modifications
wget https://github.com/msftrobiro/SAPonAzure/raw/master/temp_sap_systems/install_files/ers_install_ini.params --quiet -O /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/NW_readProfileDir.profileDir/ c\NW_readProfileDir.profileDir = /sapmnt/${SAPSID}/profile" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/nwUsers.sidadmPassword/ c\nwUsers.sidadmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/nwUsers.sapadmUID/ c\nwUsers.sapadmUID = 1001" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = 200" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = 1010" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/nw_instance_ers.ersInstanceNumber/ c\nw_instance_ers.ersInstanceNumber = $((ASCSNO + 1))" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/nw_instance_ers.ersVirtualHostname / c\nw_instance_ers.ersVirtualHostname = ${SIDLOWER}ascs02" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MASTERPW}" /tmp/${SIDLOWER}_ers_install_ini.params 
echo 'cd /usr/sap/download && mkdir SWPM && mv SWPM.sar SWPM && cd SWPM && ../sapcar -xf SWPM.sar'  >> /tmp/${SIDLOWER}_install_ers.sh
# workaround for sapinst bug?
echo 'sudo mkdir -p /usr/sap/SHX/SYS/exe' >> /tmp/${SIDLOWER}_install_ers.sh
echo 'sudo ln -s /sapmnt/SHX/exe/uc /usr/sap/SHX/SYS/exe/uc' >> /tmp/${SIDLOWER}_install_ers.sh
echo 'export SAPINST_INPUT_PARAMETERS_URL=/tmp/'${SIDLOWER}'_ers_install_ini.params' >> /tmp/${SIDLOWER}_install_ers.sh
echo 'export SAPINST_EXECUTE_PRODUCT_ID=NW_ERS:NW752.HDB.HA' >> /tmp/${SIDLOWER}_install_ers.sh
echo 'export SAPINST_SKIP_DIALOGS=true' >> /tmp/${SIDLOWER}_install_ers.sh
echo 'export SAPINST_START_GUISERVER=false' >> /tmp/${SIDLOWER}_install_ers.sh
echo 'cd /usr/sap/download/SWPM && ./sapinst' >> /tmp/${SIDLOWER}_install_ers.sh
}

execute_install_ers () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/${SIDLOWER}_ers_install_ini.params ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/${SIDLOWER}_install_ers.sh`
sudo su - ${SIDLOWER}adm  -c "sapcontrol -nr $((ASCSNO +1))-function GetProcessList"
EOF
}

execute_install_ers_interactive () {
sed -i "/SAPINST_SKIP_DIALOGS/d" /tmp/${SIDLOWER}_install_ers.sh
sed -i "/SAPINST_START_GUISERVER/d" /tmp/${SIDLOWER}_install_ers.sh
echo '### ----------------------- ###' >> /tmp/${SIDLOWER}_install_ers.sh
sed -i "/sapinst/d" /tmp/${SIDLOWER}_install_ers.sh
echo "echo 'This will prepare everything and start sapinst with the ERS installation'" >> /tmp/${SIDLOWER}_install_ers.sh
echo "echo 'You MUST logon in the browser as indicated by sapinst - just use ssh x-forward through the jumpbox'" >> /tmp/${SIDLOWER}_install_ers.sh
echo "echo 'ERS installation I just did not find a way to do fully non-interactive, blame SAP'" >> /tmp/${SIDLOWER}_install_ers.sh
echo "echo '### --------EXECUTE--------------- ###'" >> /tmp/${SIDLOWER}_install_ers.sh
echo "echo 'cd /usr/sap/download/SWPM && ./sapinst'" >> /tmp/${SIDLOWER}_install_ers.sh
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/${SIDLOWER}_ers_install_ini.params ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/${SIDLOWER}_install_ers.sh`
EOF
}

# aaaaaand action
SIDLOWER=`echo $SAPSID|awk '{print tolower($0)}'`
VNETNAME=vnet-${AZLOCTLA}${RESOURCEGROUP}-sap
VMIMAGE=SUSE:SLES-SAP:12-sp4:latest
VMTYPE=Standard_E16s_v3
DBSUBNET=`echo $SAPIP|sed 's/.\{5\}$//'`

create_ppg

if [ $INSTALLDB2 == 'true' ]; then
    for i in 1 2 
    do
    ip=14${i}; VMNAME=vm-${AZLOCTLA}${SIDLOWER}db0${i} 
    create_hana_vm
    done
else
    i=1; ip=141; VMNAME=vm-${AZLOCTLA}${SIDLOWER}db0${i}
   create_hana_vm
fi

VMTYPE=Standard_D4s_v3
APPLSUBNET=`echo ${SAPIP}|sed 's/.\{5\}$//'`
if [ $INSTALLERS == 'true' ] ; then
    for i in 1 2 
    do
    ip=1${i}; VMNAME=vm-${AZLOCTLA}${SIDLOWER}ascs0${i}
    create_app_vm
    done
else
    i=1; ip=11; VMNAME=vm-${AZLOCTLA}${SIDLOWER}ascs0${i}
    create_app_vm
fi

if [ $INSTALLAAS == 'true' ]; then
    for i in 1 2 
    do
    ip=2${i}; VMNAME=vm-${AZLOCTLA}${SIDLOWER}app0${i}
    create_app_vm
    done
else
    i=1; ip=21; VMNAME=vm-${AZLOCTLA}${SIDLOWER}app0${i}
    create_app_vm
fi

echo "###-------------------------------------###"
echo All VMs are now deployed
echo "###-------------------------------------###"
echo List of IPs for all servers 
printf '%s\n'
az vm list-ip-addresses --resource-group $RGNAME --output table |grep $SIDLOWER| awk '{print $2,$1, substr($1,8)}' > /tmp/vm_ips.txt
cat /tmp/vm_ips.txt
sudo bash -c 'cat /tmp/vm_ips.txt >> /etc/hosts'

for i in $(cat /etc/hosts |grep vm-${AZLOCTLA}${SIDLOWER} |awk '{print $3}') 
do
VMNAME=$i
echo "###-------------------------------------###"
echo Creating SAP filesystems and doing basic post-install on ${VMNAME}
printf '%s\n'
fs_create_on_all_sap_servers
done

for i in $(cat /etc/hosts |grep vm-${AZLOCTLA}${SIDLOWER} |grep db0 | awk '{print $3}') 
do
VMNAME=$i
echo "###-------------------------------------###"
echo Creating HANA filesystems on ${VMNAME}
printf '%s\n'
fs_create_on_db_servers
done

# install ascs
expiry=$(date '+%Y-%m-%dT%H:%MZ' --date "+30 minutes")
if [ -z "$STORACCURL" ]; then
    storageAccountKey=$(az storage account keys list --account-name ${STORACC} --resource-group ${STORACCRG} --query [0].value --output tsv)
fi

VMNAME=${SIDLOWER}ascs01
echo "###-------------------------------------###"
echo Creating SAP ASCS installation file and doing basic post-install on ${VMNAME}
printf '%s\n'
create_installfile_ascs
echo "###-------------------------------------###"
echo Executing SAP ASCS installation on ${VMNAME}
printf '%s\n'
execute_install_ascs
echo "###-------------------------------------###"
echo "Creating NFS server for sapmnt and trans on "${VMNAME}
printf '%s\n'
setup_nfs_server
# ASCS instance should be up and running after this
# next mount NFS volume on other app VMs
for i in $(cat /etc/hosts |grep vm-${AZLOCTLA}${SIDLOWER} | grep -v ascs01 |  grep -v db0 | awk '{print $3}') 
do
    VMNAME=$i
    echo "###-------------------------------------###"
    echo "Mounting NFS volumes /sapmnt and /usr/sap/trans on "${VMNAME}
    printf '%s\n'
    mount_nfs_export
done

# ERS install, if setup to use 2nd ascs node
if [ $INSTALLERS == 'true' ] ; then
    VMNAME=${SIDLOWER}ascs02
    create_installfile_ers
#    execute_install_ers  # doesn't work non-interactive
    execute_install_ers_interactive
fi
# ERS instance should be up and running after this

endtime=`date +%s`
runtime=$( echo "$endtime - $starttime" | bc -l )
printf '%s\n'
echo "###-------------------------------------###"
echo SAP VM deployment and ASCS installation complete, took $runtime seconds
echo "Logfile of commands stored in " ${LOGFILE}
echo "You can continue with script 3_install_DB_and_App.sh immediately"