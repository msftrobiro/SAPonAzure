#!/bin/bash
# continue on your jumpbox, NOT in your shell/cloud shell
# ideally, 1_create_jumpbox.sh should have finished without problems
# this script assumes everything is executed on the newly created jumpbox


screen -S sapsetup

source parameters.txt
LOGFILE=/tmp/2_create_SAP_infra.log
starttime=`date +%s`
echo "###-------------------------------------###"
echo "Need to authenticate you with az cli"
echo "Follow prompt to authenticate in browser window with device code displayed"
az login

if [ $? -ne 0 ];
    then
        echo "Some error occured with az login, check display"
        exit 1
fi

echo "###-------------------------------------###"
echo "Azure cli logged on successfully"
echo "Have started screen, you can detach with Control-a d. This means press the Ctrl key and the 'a' key together and release, and then press the 'd' key."
echo "Script continues to run in backgroup, you can re-attach with screen -r sapsetup"
echo "###-------------------------------------###"


az account set --subscription $AZSUB
RGNAME=RG-${AZLOCTLA}-${RESOURCEGROUP}
wget "https://saeunsapsoft.blob.core.windows.net/sapsoft/linux_tools/sockperf?sv=2018-03-28&ss=bfqt&srt=sco&sp=r&se=2023-10-04T19:12:30Z&st=2019-10-04T11:12:30Z&spr=https&sig=l1kQEWAWMYlqm08BHzHOIBykTdrL6DlpzRBYhMkPSXw%3D" -O ~/sockperf && sudo chmod ugo+x ~/sockperf
wget "https://saeunsapsoft.blob.core.windows.net/sapsoft/linux_tools/DLManager.jar?sv=2018-03-28&ss=bfqt&srt=sco&sp=r&se=2023-10-04T19:12:30Z&st=2019-10-04T11:12:30Z&spr=https&sig=l1kQEWAWMYlqm08BHzHOIBykTdrL6DlpzRBYhMkPSXw%3D" -O ~/DLManager.jar 

SIDLOWER=`echo $SAPSID|awk '{print tolower($0)}'`
VMTYPE=Standard_D4s_v3
VNETNAME=VNET-${AZLOCTLA}-${RESOURCEGROUP}-sap
VMIMAGE=SUSE:SLES-SAP:12-sp4:latest
VMNAME=VM-${AZLOCTLA}-ascs${SIDLOWER}01

printf '%s\n'
echo Creating ASCS and App Server VMs $RGNAME in $AZLOC
# ideally, you'd choose two zones (logical zones, logical to physical mapping changes PER subscription)
APPLSUBNET=`echo ${SAPIP}|sed 's/.\{5\}$//'`
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${APPLSUBNET}.10 --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-appl --nsg NSG-${AZLOCTLA}-sap-${SIDLOWER}-appl --zone 1 >>$LOGFILE 2>&1   
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --sku StandardSSD_LRS --size 65

VMNAME=VM-${AZLOCTLA}-ascs${SIDLOWER}02
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${APPLSUBNET}.11 --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-appl --nsg NSG-${AZLOCTLA}-sap-${SIDLOWER}-appl --zone 2 >>$LOGFILE 2>&1   
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --sku StandardSSD_LRS --size 65

VMNAME=VM-${AZLOCTLA}-app${SIDLOWER}01
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${APPLSUBNET}.21 --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-appl --nsg NSG-${AZLOCTLA}-sap-${SIDLOWER}-appl --zone 1 >>$LOGFILE 2>&1   
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --sku StandardSSD_LRS --size 65
VMNAME=VM-${AZLOCTLA}-app${SIDLOWER}02
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${APPLSUBNET}.22 --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-appl --nsg NSG-${AZLOCTLA}-sap-${SIDLOWER}-appl --zone 2 >>$LOGFILE 2>&1   
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --sku StandardSSD_LRS --size 65

echo "###-------------------------------------###"
echo Creating DB VMs 
printf '%s\n'
VMTYPE=Standard_E16s_v3
DBSUBNET=`echo $SAPIP|sed 's/.\{5\}$//'`
for i in 1 2
do
VMNAME=VM-${AZLOCTLA}-db${SIDLOWER}0${i}
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${DBSUBNET}.14${i} --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-db --nsg NSG-${AZLOCTLA}-sap-${SIDLOWER}-db --zone $i >>$LOGFILE 2>&1   
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --sku StandardSSD_LRS --size 65
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk2 --new --sku Premium_LRS --size 255
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk3 --new --sku Premium_LRS --size 255
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk4 --new --sku Premium_LRS --size 255
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk5 --new --sku StandardSSD_LRS --size 127
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk6 --new --sku StandardSSD_LRS --size 255
done

echo "###-------------------------------------###"
echo List of IPs for all servers 
printf '%s\n'
az vm list-ip-addresses --resource-group $RGNAME --output table |grep $SIDLOWER| awk '{print $2,$1, substr($1,8)}' > /tmp/vm_ips.txt
sudo bash -c 'cat /tmp/vm_ips.txt >> /etc/hosts'

fs_create_on_all_sap_servers () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/vm_ips.txt ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
sudo bash -c "cat /tmp/vm_ips.txt >> /etc/hosts"
sudo pvcreate /dev/disk/azure/scsi1/lun0
sudo vgcreate vg_SAP /dev/disk/azure/scsi1/lun0
sudo lvcreate -n lv_SAP_usrsap -l 30%VG vg_SAP
sudo lvcreate -n lv_SAP_sapmnt -l 30%VG vg_SAP
sudo bash -c "echo '/dev/mapper/vg_SAP-lv_SAP_sapmnt  /sapmnt   xfs      defaults      0 0' >> /etc/fstab"
sudo bash -c "echo '/dev/mapper/vg_SAP-lv_SAP_usrsap  /usr/sap   xfs      defaults      0 0' >> /etc/fstab"
sudo mkfs.xfs /dev/mapper/vg_SAP-lv_SAP_usrsap
sudo mkfs.xfs /dev/mapper/vg_SAP-lv_SAP_sapmnt
sudo mkdir /usr/sap /sapmnt
sudo mount -a
sudo sed -i 's/ResourceDisk.Format=n/ResourceDisk.Format=y/g' /etc/waagent.conf
sudo sed -i 's/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g' /etc/waagent.conf
sudo sed -i 's/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=20480/g' /etc/waagent.conf
sudo systemctl restart waagent
sudo swapon -s
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
sudo lvcreate -n lv_HANA_log -l 30%VG --stripes 3 vg_HANA
sudo lvcreate -n lv_HANA_data -l +60%VG --stripes 3 vg_HANA
sudo vgcreate vg_HANA_shared /dev/disk/azure/scsi1/lun4
sudo vgcreate vg_HANA_backup /dev/disk/azure/scsi1/lun5
sudo lvcreate -n lv_HANA_shared -l 90%VG vg_HANA_shared
sudo lvcreate -n lv_HANA_backup -l 90%VG vg_HANA_backup
sudo bash -c "echo '/dev/mapper/vg_HANA-lv_HANA_log  /hana/log   xfs      defaults      0 0' >> /etc/fstab"
sudo bash -c "echo '/dev/mapper/vg_HANA-lv_HANA_data  /hana/data   xfs      defaults      0 0' >> /etc/fstab"
sudo bash -c "echo '/dev/mapper/vg_HANA_shared-lv_HANA_shared  /hana/shared   xfs      defaults      0 0' >> /etc/fstab"
sudo bash -c "echo '/dev/mapper/vg_HANA_backup-lv_HANA_shared  /hana/backup   xfs      defaults      0 0' >> /etc/fstab"
sudo mkfs.xfs /dev/mapper/vg_HANA-lv_HANA_log
sudo mkfs.xfs /dev/mapper/vg_HANA-lv_HANA_data
sudo mkfs.xfs /dev/mapper/vg_HANA_shared-lv_HANA_shared
sudo mkfs.xfs /dev/mapper/vg_HANA_backup-lv_HANA_backup
sudo mkdir -p /hana/data /hana/log /hana/shared /hana/backup
sudo mount -a
EOF
}

for i in 1 2
do
echo "###-------------------------------------###"
echo Creating SAP filesystems and doing basic post-install on ASCS VMs
printf '%s\n'
VMNAME=ascs${SIDLOWER}0${i}
fs_create_on_all_sap_servers
echo "###-------------------------------------###"
echo Creating SAP filesystems and doing basic post-install on AppServer VMs
printf '%s\n'
VMNAME=app${SIDLOWER}0${i}
fs_create_on_all_sap_server
echo "###-------------------------------------###"
echo Creating SAP and HANA filesystems and doing basic post-install on DB VMs
printf '%s\n'
VMNAME=db${SIDLOWER}0${i}
fs_create_on_all_sap_servers
fs_create_on_db_servers
done

# install ascs
expiry=$(date '+%Y-%m-%dT%H:%MZ' --date "+30 minutes")
storageAccountKey=$(az storage account keys list --account-name ${STORACC} --resource-group ${STORACCRG} --query [0].value --output tsv)
sasToken=$(az storage blob generate-sas --account-name ${STORACC} --account-key $storageAccountKey --container-name templates --name azuredeploy.json --permissions r --expiry $expiry --output tsv)

download_url () {
shortURL=$(az storage blob url --account-name ${STORACC} --container-name ${STORCONTAINER} --name $1 --output tsv)
fullURL=$shortURL?$sasToken
echo $fullURL
}

create_installfile_ascs () {
echo "sudo mkdir /usr/sap/download && sudo chmod 777 /usr/sap/download && cd /usr/sap/download" > /tmp/${SIDLOWER}_install_ascs.sh
echo "mkdir installation" >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget '`download_url sapcar_linux`' -O /usr/sap/download/sapcar && sudo chmod ugo+x /usr/sap/download/sapcar'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget '`download_url SWPM10SP26_1-20009701.SAR`' -O /usr/sap/download/SWPM.sar'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget '`download_url kernel753_SAPEXE_300-80002573.SAR`' -O /usr/sap/download/installation/SAPEXE.SAR'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget '`download_url kernel753_dw_422-80002573.sar`' -O /usr/sap/download/installation/DW.SAR'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget '`download_url SAPHOSTAGENT42_42-20009394.SAR`' -O /usr/sap/download/installation/SAPHOSTAGENT.SAR'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget '`download_url ascs_install_ini.params`' -O /usr/sap/download/${SIDLOWER}_ascs_install_ini.params'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget '`download_url s01_ascs_instkey.pkey`' -O /usr/sap/download/instkey.pkey'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MASTERPW}" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/NW_GetSidNoProfiles.sid/ c\NW_GetSidNoProfiles.sid = ${SAPSID}" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/NW_SCS_Instance.instanceNumber/ c\NW_SCS_Instance.instanceNumber = ${ASCSNO}" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/NW_SCS_Instance.scsVirtualHostname / c\NW_SCS_Instance.scsVirtualHostname = ascs${SIDLOWER}01" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/NW_webdispatcher_Instance.scenarioSize/ c\NW_webdispatcher_Instance.scenarioSize = 500" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/NW_webdispatcher_Instance.wdHTTPPort/ c\NW_webdispatcher_Instance.wdHTTPPort = 80${ASCSNO}" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/NW_webdispatcher_Instance.wdHTTPSPort/ c\NW_webdispatcher_Instance.wdHTTPSPort = 443${ASCSNO}" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MASTERPW}" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/nwUsers.sapadmUID/ c\nwUsers.sapadmUID = 1001" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = 200" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = 1010 /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sed -i  "/nwUsers.sidadmPassword/ c\nwUsers.sidadmPassword = ${MASTERPW}" /usr/sap/download/${SIDLOWER}_ascs_install_ini.params' >> >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'cd /usr/sap/download && mkdir SWPM && mv SWPM.sar SWPM && cd SWPM && ../sapcar -xf SWPM.sar'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'sudo bash -c "export SAPINST_INPUT_PARAMETERS_URL=/usr/sap/download/${SIDLOWER}_ascs_install_ini.params && export SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_ASCS:NW752.HDB.HA && export SAPINST_SKIP_DIALOGS=true && export SAPINST_START_GUISERVER=false && cd /usr/sap/download/SWPM && ./sapinst"' >> /tmp/${SIDLOWER}_install_ascs.sh
}

execute_install_ascs () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/${SIDLOWER}_install_ascs.sh ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
chmod uo+x /tmp/${SIDLOWER}_install_ascs.sh
/tmp/${SIDLOWER}_install_ascs.sh
exit
sed -i -e 's/${MASTERPW}/pwwashere/g' /tmp/${SIDLOWER}_install_ascs.sh
EOF
}

setup_nfs_server () { 
APPLSUBNET=`echo ${SAPIP}|sed 's/.\{5\}$//'`
echo 'sudo chown ${SIDLOWER}adm:sapsys /usr/sap' > /tmp/setup_nfs_server.sh
echo 'sudo su - ${SIDLOWER}adm -c "mkdir /usr/sap/trans"' >> /tmp/setup_nfs_server.sh
echo 'sudo sh -c "echo  /sapmnt    ${APPLSUBNET}.0/24\(rw,no_root_squash\) >> /etc/exports"' >> /tmp/setup_nfs_server.sh
echo 'sudo sh -c "echo  /usr/sap/trans    ${APPLSUBNET}.0/24\(rw,no_root_squash\) >> /etc/exports"' >> /tmp/setup_nfs_server.sh
echo 'sudo systemctl enable nfsserver' >> /tmp/setup_nfs_server.sh
echo 'sudo systemctl start nfsserver' >> /tmp/setup_nfs_server.sh
echo 'sudo su - ${SIDLOWER}adm sh -c "echo dbs/hdb/schema = SAPSR3 >> /sapmnt/"${SAPSID}"/profile/DEFAULT.PFL"' >> /tmp/setup_nfs_server.sh

ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
chmod uo+x /tmp/setup_nfs_server.sh
/tmp/setup_nfs_server.sh
exit
EOF
}

VMNAME=ascs${SIDLOWER}01
echo 
create_installfile_ascs
execute_install_ascs

# ASCS instance should be up and running after this




# install ERS
create_installfile_ers () {
ssh -oStrictHostKeyChecking=no bob@vm-eun-sap-s01ascs2 << EOF
sudo mkdir /usr/sap/download && sudo chmod 777 /usr/sap/download && cd /usr/sap/download
mkdir installation
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/sapcar_linux -O /usr/sap/download/sapcar && sudo chmod ugo+x /usr/sap/download/sapcar
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/SWPM10SP26_1-20009701.SAR -O /usr/sap/download/SWPM.sar
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/kernel753_SAPEXE_300-80002573.SAR -O /usr/sap/download/installation/SAPEXE.SAR
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/kernel753_dw_422-80002573.sar -O /usr/sap/download/installation/DW.SAR
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/SAPHOSTAGENT42_42-20009394.SAR -O /usr/sap/download/installation/SAPHOSTAGENT.SAR
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/s01_ers_inifile.params
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/s01_ers_instkey.pkey -O /usr/sap/download/instkey.pkey
cd /usr/sap/download && mkdir SWPM && mv SWPM.sar SWPM && cd SWPM && ../sapcar -xf SWPM.sar

sudo su -
echo `/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{print$1}'` vm-eun-sap-s01ascs2 s01ascs2 >> /etc/hosts
export SAPINST_INPUT_PARAMETERS_URL=/usr/sap/download/s01_ers_inifile.params
export SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_ERS:NW752.HDB.HA
export SAPINST_SKIP_DIALOGS=true
export SAPINST_START_GUISERVER=false
cd /usr/sap/download/SWPM && ./sapinst
exit
EOF
}
# ERS needs some love
