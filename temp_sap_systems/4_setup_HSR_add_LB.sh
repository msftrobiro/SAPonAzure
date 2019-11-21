#!/bin/bash
# this script adds HANA replication between first and second DB node
# adds a standard internal load balancer and changes SAP config to utilize the new virtual IP address
# script should be called after right third script created DBs, loaded them and installed PAS/ASS instances
# v0.3

source parameters.txt
LOGFILE=/tmp/4_setup_HSR_add_LB.log
starttime=`date +%s`
if [[ -z $AZLOCTLA ]]; 
    then RGNAME=rg-${RESOURCEGROUP}
    else AZLOCTLA=${AZLOCTLA}-; RGNAME=rg-${AZLOCTLA}${RESOURCEGROUP}
fi
if az account show | grep -m 1 "login"; then
    echo "###-------------------------------------###"
    echo "Need to authenticate you with az cli"
    echo "Follow prompt to authenticate in browser window with device code displayed"
    az login
fi
SIDLOWER=`echo $SAPSID|awk '{print tolower($0)}'`
HANALOWER=`echo $HANASID|awk '{print tolower($0)}'`
az account set --subscription $AZSUB >>$LOGFILE 2>&1

setup_hsr () {
    echo "###-------------------------------------###"
    echo "Enabling HANA System Replication"
    echo sudo mkdir /hana/backup/db /hana/backup/logs > /tmp/setup_hsr.sh
    echo sudo chown -R ${HANALOWER}adm:sapsys /hana/backup  >> /tmp/setup_hsr.sh
    echo "sudo su - "${HANALOWER}"adm" >> /tmp/setup_hsr.sh
    echo "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d systemdb -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','log_mode')='normal' with reconfigure;\"" >> /tmp/setup_hsr.sh
    echo "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d "${HANASID}" -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','log_mode')='normal' with reconfigure;\"" >> /tmp/setup_hsr.sh
    echo "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d systemdb -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','basepath_logbackup')='/hana/backup/logs' with reconfigure;\"" >> /tmp/setup_hsr.sh
    echo "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d "${HANASID}" -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','basepath_logbackup')='/hana/backup/logs' with reconfigure;\"" >> /tmp/setup_hsr.sh
    echo "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d systemdb -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','basepath_databackup')='/hana/backup/db' with reconfigure;\"" >> /tmp/setup_hsr.sh
    echo "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d "${HANASID}" -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','basepath_databackup')='/hana/backup/db' with reconfigure;\"" >> /tmp/setup_hsr.sh
    echo "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d "${HANASID}" -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','basepath_databackup')='/hana/backup/db' with reconfigure;\"" >> /tmp/setup_hsr.sh
    echo "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d systemdb -Ajm \"backup data using file (' "`date +backup%Y%m%d-%H%M`" ')\"" > /tmp/setup_hsr_primary.sh
    echo "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d "${HANASID}" -Ajm \"backup data using file ('"`date +backup%Y%m%d-%H%M`" ')\"" >> /tmp/setup_hsr_primary.sh
    echo "hdbnsutil -sr_enable --name="${HANASID}"1" >> /tmp/setup_hsr_primary.sh
# this is very ugly but don't want to alter ssh communication between nodes to exchange keys for replication and setup ssh keys for hanasidadm
    echo "tar -czPf /tmp/repl_keys.tgz /usr/sap/"${HANASID}"/SYS/global/security/rsecssfs/"  >> /tmp/setup_hsr_primary.sh
    echo "chmod o+r /tmp/repl_keys.tgz"  >> /tmp/setup_hsr_primary.sh
    echo "tar -xzPf /tmp/repl_keys.tgz" > /tmp/setup_hsr_secondary.sh
    echo "HDB stop" >> /tmp/setup_hsr_secondary.sh
    echo "rm /usr/sap/"${HANASID}"/SYS/global/security/rsecssfs/data/SSFS*" >> /tmp/setup_hsr_secondary.sh
    echo "hdbnsutil -sr_register --name="${HANASID}"2 --remoteHost="${SIDLOWER}"db01 --remoteInstance="${HDBNO}" --replicationMode=sync --remoteName="${HANASID}"1 --operationMode=logreplay" >> /tmp/setup_hsr_secondary.sh
    echo "HDB start" >> /tmp/setup_hsr_secondary.sh
}

# setup load balancer
# this is likely best split into an ILB and external portion but for now, only deploying ILBs
create_lb () {
LBNAME=lb-${AZLOCTLA}${SIDLOWER}-${app}-${intext}
VNETNAME=vnet-${AZLOCTLA}${RESOURCEGROUP}-sap

if [ "$intext" == "int" ]; then 
az network lb create --resource-group $RGNAME --name $LBNAME --private-ip-address ${APPLSUBNET}.${ip} --frontend-ip-name ipconfig-${LBNAME} --backend-pool-name ${LBNAME}-bepool --vnet-name $VNETNAME --subnet ${VNETNAME}-${app} --sku standard  >>$LOGFILE 2>&1
fi

if [ "$intext" == "ext" ]; then 
az network public-ip create --resource-group $RGNAME --name ${LBNAME}-pip --sku standard  >>$LOGFILE 2>&1
az network lb create --resource-group $RGNAME --name $LBNAME --public-ip-address ${LBNAME}-pip --public-ip-address-allocation dynamic --frontend-ip-name ipconfig-${LBNAME} --backend-pool-name ${LBNAME}-bepool --sku standard  >>$LOGFILE 2>&1
fi

if [ "$app" == "ascs" ]; then port=36${ASCSNO}; fi
if [ "$app" == "db" ]; then port=3${HDBNO}15; fi

az network lb probe create --resource-group $RGNAME --lb-name $LBNAME --name ${LBNAME}-HealthProbe --protocol tcp --port ${port}  >>$LOGFILE 2>&1
az network lb rule create --resource-group $RGNAME --lb-name $LBNAME --name ${LBNAME}-rule1 --protocol tcp --frontend-port ${port} --backend-port ${port} --frontend-ip-name ipconfig-${LBNAME} --backend-pool-name ${LBNAME}-bepool --probe-name ${LBNAME}-HealthProbe   >>$LOGFILE 2>&1

for vm in $(cat /etc/hosts |grep  vm-${AZLOCTLA}${SIDLOWER}${app}0 |awk '{print $2}') 
do
az network nic ip-config update --resource-group $RGNAME --name ipconfig${vm} --nic-name ${vm}VMNic --lb-name $LBNAME --lb-address-pool ${LBNAME}-bepool >>$LOGFILE 2>&1
done
}

# let's go
if [ $INSTALLDB2 == 'true' ]; then
    setup_hsr
    ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${SIDLOWER}db01 -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
    `cat /tmp/setup_hsr.sh`
    echo "Starting backup of database to enable replication, this will run a few minutes"
    `cat /tmp/setup_hsr_primary.sh`
EOF
    scp -oStrictHostKeyChecking=no ${ADMINUSR}@${SIDLOWER}db01:/tmp/repl_keys.tgz /tmp/repl_keys.tgz
    scp -oStrictHostKeyChecking=no /tmp/repl_keys.tgz ${ADMINUSR}@${SIDLOWER}db02:/tmp/repl_keys.tgz
    rm /tmp/repl_keys.tgz
    ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${SIDLOWER}db02 -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
    `cat /tmp/setup_hsr.sh`
    `cat /tmp/setup_hsr_secondary.sh`
EOF
    echo "###-------------------------------------###"
    echo "HANA replication enabled on "${SIDLOWER}"db01 and "${SIDLOWER}"db02"
# DB LB only internal
app=db
intext=int
APPLSUBNET=`echo ${SAPIP}|sed 's/.\{5\}$//'`
ip=150
    echo "###-------------------------------------###"
    echo "Creating Internal Load Balancer for database servers"
create_lb
    echo "###-------------------------------------###"
    echo ${LBNAME}" created and listening on IP "${APPLSUBNET}.${ip}" listening on connections on port 3"${HDBNO}"15"
fi

if [ $INSTALLERS == 'true' ]; then
app=ascs
intext=int
APPLSUBNET=`echo ${SAPIP}|sed 's/.\{5\}$//'`
ip=100
    echo "###-------------------------------------###"
    echo "Creating Internal Load Balancer for ASCS servers"
create_lb
    echo "###-------------------------------------###"
    echo ${LBNAME}" created and listening on IP "${APPLSUBNET}.${ip}" listening on connections on port 36"${ASCSNO}
fi


if [ $INSTALLDB2 == 'true' ]; then 
    echo "###-------------------------------------###"
    echo "You can change the application server(s) to utilize the HANA load balancer"
    echo "By executing following as "${SIDLOWER}" on all deployed app servers (1 or 2)"
    echo "hdbuserstore set DEFAULT "${APPLSUBNET}".150@"${HANASID}" SAPSR3 "${MASTERPW}
    echo "You can then play around with HANA failover in a cluster-like setup"
fi
if [ $INSTALLERS == 'true' ]; then
    echo "###-------------------------------------###"
    echo "You can specify the ASCS load balancer in SAP profiles"
    echo "Host file/DNS entry first needed for IP "${APPLSUBNET}".100"
    echo "Change entries pointing towards the load balanced IP in SAP default and instance profiles"
    echo "Also rename the ASCS profile to use the load balancer hostname of your choosing"
    echo "###-------------------------------------###"

# curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2017-08-01&format=text"fgv