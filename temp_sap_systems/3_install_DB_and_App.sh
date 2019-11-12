#!/bin/bash
# continue on your jumpbox, NOT in your shell/cloud shell
# ideally, 1_create_jumpbox.sh should have finished without problems
# this script assumes everything is executed on the newly created jumpbox
# version 0.2

source parameters.txt
LOGFILE=/tmp/3_install_DB_and_App.log
if [[ -z $AZLOCTLA ]]; 
    then RGNAME=rg-${RESOURCEGROUP}
    else AZLOCTLA=${AZLOCTLA}-; RGNAME=rg-${AZLOCTLA}${RESOURCEGROUP}
fi
SIDLOWER=`echo $SAPSID|awk '{print tolower($0)}'`
HANALOWER=`echo $HANASID|awk '{print tolower($0)}'`
starttime=`date +%s`

# make sure azure cli is logged in
if az account show | grep -m 1 "login"; then
    echo "###-------------------------------------###"
    echo "Need to authenticate you with az cli"
    echo "Follow prompt to authenticate in browser window with device code displayed"
    az login
fi

if [ $? -ne 0 ];
    then
        echo "Some error occured with az login, check display"
        exit 1
    else
    echo "###-------------------------------------###"
    echo "Azure cli logged on successfully"
    echo "###-------------------------------------###"
fi

# make sure azure cli is installed
if ! [ -x "$(command -v az)" ]; then
  echo 'Error: Azure CLI is not installed.  See: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli' >&2
  exit 1
fi

az account set --subscription $AZSUB >>$LOGFILE 2>&1

expiry=$(date '+%Y-%m-%dT%H:%MZ' --date "+30 minutes")
if [ -z "$STORACCURL" ]; then
    storageAccountKey=$(az storage account keys list --account-name ${STORACC} --resource-group ${STORACCRG} --query [0].value --output tsv)
fi

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

db_install () {
    echo "sudo mkdir /hana/shared/download && sudo chmod -R 777 /hana/shared/download" > /tmp/${HANALOWER}_install_hana.sh
    echo 'wget "'`download_url sapcar_linux`'" -O /hana/shared/download/sapcar --quiet && sudo chmod ugo+x /hana/shared/download/sapcar'  >> /tmp/${HANALOWER}_install_hana.sh
    echo 'wget "'`download_url IMDB_CLIENT.SAR`'" -O /hana/shared/download/IMDB_CLIENT.SAR --quiet'  >> /tmp/${HANALOWER}_install_hana.sh
    echo 'wget "'`download_url IMDB_SERVER.SAR`'" -O /hana/shared/download/IMDB_SERVER.SAR --quiet'  >> /tmp/${HANALOWER}_install_hana.sh
    # doctor up the inifile
    wget https://github.com/msftrobiro/SAPonAzure/raw/master/temp_sap_systems/install_files/hdb_install.rsp -O /tmp/${HANALOWER}_install_hana.params
    sed -i  "/hostname=s01db1/ c\hostname= ${VMNAME}" /tmp/${HANALOWER}_install_hana.params
    sed -i  "/sid=H01/ c\sid=${HANASID}" /tmp/${HANALOWER}_install_hana.params
    sed -i  "/number=40/ c\number=${HDBNO}" /tmp/${HANALOWER}_install_hana.params
    sed -i  "/master_password=MasterPW/ c\master_password=${MASTERPW}" /tmp/${HANALOWER}_install_hana.params
    sed -i  "/use_master_password/ c\use_master_password=y" /tmp/${HANALOWER}_install_hana.params
    sed -i  "/userid=1040/ c\userid=10${HDBNO}" /tmp/${HANALOWER}_install_hana.params
    sed -i  "/groupid=200/ c\groupid=200" /tmp/${HANALOWER}_install_hana.params
    scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/${HANALOWER}_install_hana.params ${ADMINUSR}@${VMNAME}:/tmp
    # hana install
    echo 'sudo su -' >> /tmp/${HANALOWER}_install_hana.sh
    echo 'cd /hana/shared/download && ./sapcar -xf "*.SAR"'  >> /tmp/${HANALOWER}_install_hana.sh
    echo 'cd /hana/shared/download/SAP_HANA_DATABASE && ./hdblcm --sid='${HANASID}' --configfile=/tmp/'${HANALOWER}'_install_hana.params -b --ignore=check_signature_file' >> /tmp/${HANALOWER}_install_hana.sh
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/${HANALOWER}_install_hana.sh`
sudo su - ${HANALOWER}adm -c "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d systemdb -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','log_mode')='overwrite' with reconfigure;\""
sudo su - ${HANALOWER}adm -c "hdbsql -i "${HDBNO}" -n localhost -u system -p "${MASTERPW}" -d "${HANASID}" -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','log_mode')='overwrite' with reconfigure;\""
exit
EOF
}

# install HANA on DB VMs
if [ $INSTALLDB2 == 'true' ]; then
    for i in 1 2 
    do
    VMNAME=${SIDLOWER}db0${i}
    echo "###-------------------------------------###"
    echo Installing HANA Database ${HANASID} on ${VMNAME}
    printf '%s\n'
    db_install
    done 
else
    i=1
    VMNAME=${SIDLOWER}db0${i}
    echo "###-------------------------------------###"
    echo Installing HANA Database ${HANASID} on ${VMNAME}
    printf '%s\n'
    db_install
fi

# now to move to the PAS install
create_installfile_db_load () {
    echo 'sudo mkdir /usr/sap/download && sudo chmod 777 /usr/sap/download' > /tmp/${SIDLOWER}_db_load.sh
    echo 'cd /usr/sap/download && mkdir installation' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'wget "'`download_url sapcar_linux`'" -O /usr/sap/download/sapcar --quiet && sudo chmod ugo+x /usr/sap/download/sapcar' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'wget "'`download_url SWPM.SAR`'" -O /usr/sap/download/SWPM.sar --quiet' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'wget "'`download_url SAPEXE.SAR`'" -O /usr/sap/download/installation/SAPEXE.SAR --quiet' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'wget "'`download_url DW.SAR`'" -O /usr/sap/download/installation/DW.SAR --quiet' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'wget "'`download_url SAPHOSTAGENT.SAR`'" -O /usr/sap/download/installation/SAPHOSTAGENT.SAR --quiet' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'wget "'`download_url SAPEXEDB.SAR`'" -O /usr/sap/download/installation/SAPEXEDB.SAR --quiet' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'wget "'`download_url nw752_exp.zip`'" -O /usr/sap/download/nw752_export.zip --quiet' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'wget "'`download_url IMDB_CLIENT.SAR`'" -O /usr/sap/download/IMDB_CLIENT.SAR --quiet' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'cd /usr/sap/download && ./sapcar -xf IMDB_CLIENT.SAR && rm IMDB_CLIENT.SAR' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'cd /usr/sap/download && unzip nw752_export.zip && rm nw752_export.zip' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'wget "'`download_url nw752_lang.zip`'" -O /usr/sap/download/nw752_lang.zip --quiet' >> /tmp/${SIDLOWER}_db_load.sh
    echo 'cd /usr/sap/download && unzip nw752_lang.zip && rm nw752_lang.zip' >> /tmp/${SIDLOWER}_db_load.sh
    # doctor up the inifile
    wget https://github.com/msftrobiro/SAPonAzure/raw/master/temp_sap_systems/install_files/db_load_ini.params -O /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_DB.abapSchemaName/ c\NW_HDB_DB.abapSchemaName = SAPSR3" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_DB.abapSchemaPassword/ c\NW_HDB_DB.abapSchemaPassword = ${MASTERPW}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MASTERPW}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/HDB_Userstore.doNotResolveHostnames/ c\HDB_Userstore.doNotResolveHostnames = ${SIDLOWER}db01" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_ABAP_Import_Dialog.dbCodepage/ c\NW_ABAP_Import_Dialog.dbCodepage = 4103" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_ABAP_Import_Dialog.migmonJobNum/ c\NW_ABAP_Import_Dialog.migmonJobNum = 6" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MASTERPW}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_GetSidNoProfiles.sid/ c\NW_GetSidNoProfiles.sid = ${SAPSID}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbhost/ c\NW_HDB_getDBInfo.dbhost = ${SIDLOWER}db01" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${HANASID}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.instanceNumber/ c\NW_HDB_getDBInfo.instanceNumber = ${HDBNO}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.systemDbPassword/ c\NW_HDB_getDBInfo.systemDbPassword = ${MASTERPW}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.systemPassword/ c\NW_HDB_getDBInfo.systemPassword = ${MASTERPW}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.systemid/ c\NW_HDB_getDBInfo.systemid = ${HANASID}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_getFQDN.FQDN/ c\NW_getFQDN.FQDN = contoso.local" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_getFQDN.setFQDN/ c\NW_getFQDN.setFQDN = false" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_readProfileDir.profilesAvailable/ c\NW_readProfileDir.profilesAvailable = false" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/nwUsers.sapadmUID/ c\nwUsers.sapadmUID = 1001" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = 200" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = 1010" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/nwUsers.sidadmPassword/ c\nwUsers.sidadmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/SAPINST.CD.PACKAGE.EXP1/ c\SAPINST.CD.PACKAGE.EXP1=/usr/sap/download/export_cd" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/SAPINST.CD.PACKAGE.LANG/ c\SAPINST.CD.PACKAGE.LANG=/usr/sap/download/lang_cd" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/SAPINST.CD.PACKAGE.HDBCLIENT/ c\SAPINST.CD.PACKAGE.HDBCLIENT=/usr/sap/download/SAP_HANA_CLIENT" /tmp/${SIDLOWER}_db_load_ini.params
echo 'sudo su -' >> /tmp/${SIDLOWER}_db_load.sh
echo 'cd /usr/sap/download && mkdir SWPM && mv SWPM.sar SWPM && cd SWPM && ../sapcar -xf SWPM.sar' >> /tmp/${SIDLOWER}_db_load.sh
echo 'export SAPINST_INPUT_PARAMETERS_URL=/tmp/'${SIDLOWER}'_db_load_ini.params' >> /tmp/${SIDLOWER}_db_load.sh
echo 'export SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_DB:NW752.HDB.HA' >> /tmp/${SIDLOWER}_db_load.sh
echo 'export SAPINST_SKIP_DIALOGS=true' >> /tmp/${SIDLOWER}_db_load.sh
echo 'export SAPINST_START_GUISERVER=false' >> /tmp/${SIDLOWER}_db_load.sh
echo 'cd /usr/sap/download/SWPM && ./sapinst' >> /tmp/${SIDLOWER}_db_load.sh
}

execute_db_load () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/${SIDLOWER}_db_load_ini.params ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/${SIDLOWER}_db_load.sh`
EOF
}

starttimedbload=`date +%s`
VMNAME=${SIDLOWER}app01
echo "###-------------------------------------###"
echo Prepare DB load configuration of ${SAPSID} Netweaver 7.52 on ${VMNAME}
printf '%s\n'
create_installfile_db_load
echo "###-------------------------------------###"
echo Starting DB load of ${SAPSID} Netweaver 7.52 on ${VMNAME}
printf '%s\n'
execute_db_load
# DB should be loaded after this
endtimedbload=`date +%s`
runtimedbload=$( echo "$endtimedbload - $starttimedbload" | bc -l )
echo "###-------------------------------------###"
echo DB load of ${SAPSID} Netweaver 7.52 on ${VMNAME} completed in ${runtimedbload} seconds
printf '%s\n'

create_installfile_pas () {
    echo 'wget "'`download_url IGSEXE.SAR`'" -O /usr/sap/download/installation/IGSEXE.SAR --quiet' >> /tmp/${SIDLOWER}_pas_install.sh
    echo 'wget "'`download_url IGSHELPER.SAR`'" -O /usr/sap/download/installation/IGSHELPER.SAR --quiet' >> /tmp/${SIDLOWER}_pas_install.sh
    # doctor up the inifile
    wget https://github.com/msftrobiro/SAPonAzure/raw/master/temp_sap_systems/install_files/pas_install_ini.params -O /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/HDB_Schema_Check_Dialogs.schemaName/ c\HDB_Schema_Check_Dialogs.schemaName = SAPSR3" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_HDB_DB.abapSchemaName/ c\NW_HDB_DB.abapSchemaName = SAPSR3" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_HDB_DB.abapSchemaPassword/ c\NW_HDB_DB.abapSchemaPassword = ${MASTERPW}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MASTERPW}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/HDB_Userstore.doNotResolveHostnames/ c\HDB_Userstore.doNotResolveHostnames = ${SIDLOWER}db01" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_CI_Instance.ascsVirtualHostname/ c\NW_CI_Instance.ascsVirtualHostname = ${SIDLOWER}ascs01" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_CI_Instance.ciInstanceNumber/ c\NW_CI_Instance.ciInstanceNumber = ${PASNO}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_CI_Instance.ciVirtualHostname/ c\NW_CI_Instance.ciVirtualHostname = ${SIDLOWER}app01" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_CI_Instance.scsVirtualHostname/ c\NW_CI_Instance.scsVirtualHostname = ${SIDLOWER}ascs01" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MASTERPW}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbhost/ c\NW_HDB_getDBInfo.dbhost = ${SIDLOWER}db01" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.instanceNumber/ c\NW_HDB_getDBInfo.instanceNumber = ${HDBNO}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${HANASID}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.systemid/ c\NW_HDB_getDBInfo.systemid = ${HANASID}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.systemDbPassword/ c\NW_HDB_getDBInfo.systemDbPassword = ${MASTERPW}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.systemPassword/ c\NW_HDB_getDBInfo.systemPassword = ${MASTERPW}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_checkMsgServer.abapMSPort/ c\NW_checkMsgServer.abapMSPort = 36${ASCSNO}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_getFQDN.FQDN/ c\NW_getFQDN.FQDN = contoso.local" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_getFQDN.setFQDN/ c\NW_getFQDN.setFQDN = false" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/NW_readProfileDir.profileDir/ c\NW_readProfileDir.profileDir = /sapmnt/${SAPSID}/profile" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = 200" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = 1010" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/storageBasedCopy.hdb.instanceNumber/ c\storageBasedCopy.hdb.instanceNumber = ${HDBNO}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/storageBasedCopy.hdb.systemPassword/ c\storageBasedCopy.hdb.systemPassword = ${MASTERPW}" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/SAPINST.CD.PACKAGE.EXP1/ c\SAPINST.CD.PACKAGE.EXP1=/usr/sap/download/export_cd" /tmp/${SIDLOWER}_pas_install_ini.params
    sed -i  "/SAPINST.CD.PACKAGE.HDBCLIENT/ c\SAPINST.CD.PACKAGE.HDBCLIENT=/usr/sap/download/SAP_HANA_CLIENT" /tmp/${SIDLOWER}_pas_install_ini.params
echo 'sudo su -' >> /tmp/${SIDLOWER}_pas_install.sh
echo 'export SAPINST_INPUT_PARAMETERS_URL=/tmp/'${SIDLOWER}'_pas_install_ini.params' >> /tmp/${SIDLOWER}_pas_install.sh
echo 'export SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_CI:NW752.HDB.HA' >> /tmp/${SIDLOWER}_pas_install.sh
echo 'export SAPINST_SKIP_DIALOGS=true' >> /tmp/${SIDLOWER}_pas_install.sh
echo 'export SAPINST_START_GUISERVER=false' >> /tmp/${SIDLOWER}_pas_install.sh
echo 'cd /usr/sap/download/SWPM && ./sapinst' >> /tmp/${SIDLOWER}_pas_install.sh
}

execute_pas_install () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/${SIDLOWER}_pas_install_ini.params ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/${SIDLOWER}_pas_install.sh`
sudo su - ${SIDLOWER}adm  -c "sapcontrol -nr ${PASNO} -function GetProcessList"
EOF
}

starttimepasinstall=`date +%s`
VMNAME=${SIDLOWER}app01
echo "###-------------------------------------###"
echo Prepare PAS insstallation of ${SAPSID} Netweaver 7.52 on ${VMNAME}
printf '%s\n'
create_installfile_pas
echo "###-------------------------------------###"
echo Starting PAS install of ${SAPSID} Netweaver 7.52 on ${VMNAME}
printf '%s\n'
execute_pas_install
# DB should be loaded after this
endtimepasinstall=`date +%s`
runtimepasinstall=$( echo "$endtimepasinstall - $starttimepasinstall" | bc -l )
echo "###-------------------------------------###"
echo PAS install of ${SAPSID} Netweaver 7.52 on ${VMNAME} completed in ${runtimepasinstall} seconds
printf '%s\n'

create_installfile_aas () {
    echo 'sudo mkdir /usr/sap/download && sudo chmod 777 /usr/sap/download' > /tmp/${SIDLOWER}_aas_install.sh
    echo 'cd /usr/sap/download && mkdir installation' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'wget "'`download_url sapcar_linux`'" -O /usr/sap/download/sapcar --quiet && sudo chmod ugo+x /usr/sap/download/sapcar' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'wget "'`download_url SWPM.SAR`'" -O /usr/sap/download/SWPM.sar --quiet' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'wget "'`download_url SAPEXE.SAR`'" -O /usr/sap/download/installation/SAPEXE.SAR --quiet' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'wget "'`download_url DW.SAR`'" -O /usr/sap/download/installation/DW.SAR --quiet' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'wget "'`download_url SAPHOSTAGENT.SAR`'" -O /usr/sap/download/installation/SAPHOSTAGENT.SAR --quiet' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'wget "'`download_url SAPEXEDB.SAR`'" -O /usr/sap/download/installation/SAPEXEDB.SAR --quiet' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'wget "'`download_url nw752_exp.zip`'" -O /usr/sap/download/nw752_export.zip --quiet' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'wget "'`download_url IMDB_CLIENT.SAR`'" -O /usr/sap/download/IMDB_CLIENT.SAR --quiet' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'cd /usr/sap/download && ./sapcar -xf IMDB_CLIENT.SAR && rm IMDB_CLIENT.SAR' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'cd /usr/sap/download && unzip nw752_export.zip && rm nw752_export.zip' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'wget "'`download_url IGSEXE.SAR`'" -O /usr/sap/download/installation/IGSEXE.SAR --quiet' >> /tmp/${SIDLOWER}_aas_install.sh
    echo 'wget "'`download_url IGSHELPER.SAR`'" -O /usr/sap/download/installation/IGSHELPER.SAR --quiet' >> /tmp/${SIDLOWER}_aas_install.sh
    # doctor up the inifile
    wget https://github.com/msftrobiro/SAPonAzure/raw/master/temp_sap_systems/install_files/aas_install_ini.params -O /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/HDB_Schema_Check_Dialogs.schemaName/ c\HDB_Schema_Check_Dialogs.schemaName = SAPSR3" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_HDB_DB.abapSchemaName/ c\NW_HDB_DB.abapSchemaName = SAPSR3" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_HDB_DB.abapSchemaPassword/ c\NW_HDB_DB.abapSchemaPassword = ${MASTERPW}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MASTERPW}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/HDB_Userstore.doNotResolveHostnames/ c\HDB_Userstore.doNotResolveHostnames = ${SIDLOWER}db01" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_AS.instanceNumber/ c\NW_AS.instanceNumber = $((PASNO + 1))" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_DI_Instance.virtualHostname/ c\NW_DI_Instance.virtualHostname = ${SIDLOWER}app02" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_CI_Instance.ciVirtualHostname/ c\NW_CI_Instance.ciVirtualHostname = ${SIDLOWER}app01" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_CI_Instance.scsVirtualHostname/ c\NW_CI_Instance.scsVirtualHostname = ${SIDLOWER}ascs01" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MASTERPW}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbhost/ c\NW_HDB_getDBInfo.dbhost = ${SIDLOWER}db01" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.instanceNumber/ c\NW_HDB_getDBInfo.instanceNumber = ${HDBNO}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${HANASID}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.systemid/ c\NW_HDB_getDBInfo.systemid = ${HANASID}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.systemDbPassword/ c\NW_HDB_getDBInfo.systemDbPassword = ${MASTERPW}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_HDB_getDBInfo.systemPassword/ c\NW_HDB_getDBInfo.systemPassword = ${MASTERPW}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_checkMsgServer.abapMSPort/ c\NW_checkMsgServer.abapMSPort = 36${ASCSNO}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_getFQDN.FQDN/ c\NW_getFQDN.FQDN = contoso.local" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_getFQDN.setFQDN/ c\NW_getFQDN.setFQDN = false" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/NW_readProfileDir.profileDir/ c\NW_readProfileDir.profileDir = /sapmnt/${SAPSID}/profile" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = 200" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = 1010" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/nwUsers.sapadmUID/ c\nwUsers.sapadmUID = 1001" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/storageBasedCopy.hdb.instanceNumber/ c\storageBasedCopy.hdb.instanceNumber = ${HDBNO}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/storageBasedCopy.hdb.systemPassword/ c\storageBasedCopy.hdb.systemPassword = ${MASTERPW}" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/SAPINST.CD.PACKAGE.EXP1/ c\SAPINST.CD.PACKAGE.EXP1=/usr/sap/download/export_cd" /tmp/${SIDLOWER}_aas_install_ini.params
    sed -i  "/SAPINST.CD.PACKAGE.HDBCLIENT/ c\SAPINST.CD.PACKAGE.HDBCLIENT=/usr/sap/download/SAP_HANA_CLIENT" /tmp/${SIDLOWER}_aas_install_ini.params
echo 'sudo su -' >> /tmp/${SIDLOWER}_aas_install.sh
echo 'cd /usr/sap/download && mkdir SWPM && mv SWPM.sar SWPM && cd SWPM && ../sapcar -xf SWPM.sar' >> /tmp/${SIDLOWER}_aas_install.sh
echo 'export SAPINST_INPUT_PARAMETERS_URL=/tmp/'${SIDLOWER}'_aas_install_ini.params' >> /tmp/${SIDLOWER}_aas_install.sh
echo 'export SAPINST_EXECUTE_PRODUCT_ID=NW_DI:NW752.HDB.HA' >> /tmp/${SIDLOWER}_aas_install.sh
echo 'export SAPINST_SKIP_DIALOGS=true' >> /tmp/${SIDLOWER}_aas_install.sh
echo 'export SAPINST_START_GUISERVER=false' >> /tmp/${SIDLOWER}_aas_install.sh
echo 'cd /usr/sap/download/SWPM && ./sapinst' >> /tmp/${SIDLOWER}_aas_install.sh
}

execute_aas_install () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/${SIDLOWER}_aas_install_ini.params ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/${SIDLOWER}_aas_install.sh`
sudo su - ${SIDLOWER}adm  -c "sapcontrol -nr $((PASNO + 1)) -function GetProcessList"
EOF
}

if [ $INSTALLAAS == 'true' ]; then
    starttimeaasinstall=`date +%s`
    VMNAME=${SIDLOWER}app02
    echo "###-------------------------------------###"
    echo Prepare AAS insstallation of ${SAPSID} Netweaver 7.52 on ${VMNAME}
    printf '%s\n'
    create_installfile_aas
    echo "###-------------------------------------###"
    echo Starting AAS install of ${SAPSID} Netweaver 7.52 on ${VMNAME}
    printf '%s\n'
    execute_aas_install
    # AAS installed
    endtimeaasinstall=`date +%s`
    runtimeaasinstall=$( echo "$endtimeaasinstall - $starttimeaasinstall" | bc -l )
    echo "###-------------------------------------###"
    echo AAS install of ${SAPSID} Netweaver 7.52 on ${VMNAME} completed in ${runtimepasinstall} seconds
    printf '%s\n'
fi


