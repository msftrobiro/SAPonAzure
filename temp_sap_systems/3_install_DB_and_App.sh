#!/bin/bash
# continue on your jumpbox, NOT in your shell/cloud shell
# ideally, 1_create_jumpbox.sh should have finished without problems
# this script assumes everything is executed on the newly created jumpbox


screen -dm -S sapsetup

source parameters.txt
LOGFILE=/tmp/3_install_DB_and_App.log
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
echo "Script continues to run in background, you can re-attach with screen -r sapsetup"
echo "###-------------------------------------###"


az account set --subscription $AZSUB >>$LOGFILE 2>&1
RGNAME=RG-${AZLOCTLA}-${RESOURCEGROUP}
SIDLOWER=`echo $SAPSID|awk '{print tolower($0)}'`
HANALOWER=`echo $HANASID|awk '{print tolower($0)}'`

expiry=$(date '+%Y-%m-%dT%H:%MZ' --date "+30 minutes")
storageAccountKey=$(az storage account keys list --account-name ${STORACC} --resource-group ${STORACCRG} --query [0].value --output tsv)

download_url () {
sasToken=$(az storage blob generate-sas --account-name ${STORACC} --account-key $storageAccountKey --container-name ${STORCONTAINER} --name $1 --permissions r --expiry $expiry --output tsv)
shortURL=$(az storage blob url --account-name ${STORACC} --container-name ${STORCONTAINER} --name $1 --output tsv)
fullURL=$shortURL?$sasToken
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
VMNAME=${SIDLOWER}db01
db_install
VMNAME=${SIDLOWER}db02
db_install

# now to move to the PAS install
db_load () {
    echo 'sudo mkdir /usr/sap/download && sudo chmod 777 /usr/sap/download && cd /usr/sap/download' > /tmp/${SIDLOWER}_db_load.sh
    echo 'mkdir installation'
    echo 'wget "'`download_url sapcar_linux`'" -O /hana/shared/download/sapcar --quiet && sudo chmod ugo+x /hana/shared/download/sapcar' >> /tmp/${SIDLOWER}_db_load.sh
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
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${HANASID}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${HANASID}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${HANASID}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${HANASID}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${HANASID}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${HANASID}" /tmp/${SIDLOWER}_db_load_ini.params
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${HANASID}" /tmp/${SIDLOWER}_db_load_ini.params

}
ssh -oStrictHostKeyChecking=no bob@vm-eun-sap-s01app1 << EOF
EOF

wget https://saeunsapsoft.blob.core.windows.net/sapsoft/s01_db_inifile.params
wget https://saeunsapsoft.blob.core.windows.net/sapsoft/s01_db_instkey.pkey -O /usr/sap/download/instkey.pkey
cd /usr/sap/download && mkdir SWPM && mv SWPM.sar SWPM && cd SWPM && ../sapcar -xf SWPM.sar
sudo su -
export SAPINST_INPUT_PARAMETERS_URL=/usr/sap/download/s01_db_inifile.params
export SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_DB:NW752.HDB.HA
export SAPINST_SKIP_DIALOGS=true
export SAPINST_START_GUISERVER=false
cd /usr/sap/download/SWPM && ./sapinst
EOF

aas_install () {

}

# DB should be loaded after this