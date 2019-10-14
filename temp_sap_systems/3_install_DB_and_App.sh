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
echo "Script continues to run in backgroup, you can re-attach with screen -r sapsetup"
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
    echo 'wget "'`download_url sapcar_linux`'" -O /hana/shared/download/sapcar && sudo chmod ugo+x /hana/shared/download/sapcar'  >> /tmp/${HANALOWER}_install_hana.sh
    echo 'wget "'`download_url IMDB_CLIENT20_004_139-80002082.SAR`'" -O /hana/shared/download/IMDB_CLIENT.SAR'  >> /tmp/${HANALOWER}_install_hana.sh
    echo 'wget "'`download_url IMDB_SERVER20_037_1-80002031.SAR`'" -O /hana/shared/download/IMDB_SERVER.SAR'  >> /tmp/${HANALOWER}_install_hana.sh
    echo 'wget "'`download_url s01_hdb_install.rsp`'" -O /hana/shared/download/install_hana.params'  >> /tmp/${HANALOWER}_install_hana.sh
    echo 'sudo cd /hana/shared/download && ./sapcar -xf "*.SAR"'  >> /tmp/${HANALOWER}_install_hana.sh
    echo 'sudo cd /hana/shared/download/SAP_HANA_DATABASE && ./hdblcm --sid='${HANALOWER}' --configfile=/hana/shared/download/install_hana.params -b --ignore=check_signature_file' >> /tmp/${HANALOWER}_install_hana.sh

sudo su - ${HANALOWER}adm -c "hdbsql -i "${HANANO}" -n localhost -u system -p "${MASTERPW}" -d systemdb -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','log_mode')='overwrite' with reconfigure;\""
sudo su - ${HANALOWER}adm -c "hdbsql -i "${HANANO}" -n localhost -u system -p "${MASTERPW}" -d "${HANASID}" -Ajm \"alter system alter configuration ('global.ini','SYSTEM') SET ('persistence','log_mode')='overwrite' with reconfigure;\""

ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/${HANALOWER}_install_hana.sh`
exit
EOF
}

VMNAME=${SIDLOWER}db01