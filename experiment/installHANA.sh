#!/bin/bash

# Setting variables passed in
SAPCAR_URL=$1
SAP_HOST_URL=$2
HDB_SERVER_URL=$3
SAP_SID=$4
SAP_HOST_NAME=$5
SAP_INSTANCE_NUM=$6
SAP_ADM_PW=$7
SID_ADM_PW=$8
SYSTEM_PW=$6
# Creating /hana/shared/install and moving config templates
mkdir /hana/shared/install
cd /hana/shared/install
# Download the bits
wget -O SAPCAR_1014-80000935.EXE $SAPCAR_URL
wget -O SIGNATURE.SMF $SAP_HOST_URL
wget -O IMDB_SERVER100_122_17-10009569.SAR $HDB_SERVER_URL

chmod 755 ./SAPCAR_1014-80000935.EXE

# Extract the bits
./SAPCAR_1014-80000935.EXE -manifest SIGNATURE.SMF -xvf IMDB_SERVER100_122_17-10009569.SAR

# Generate the config and passwords
awk -v sap_sid="$SAP_SID" -v sap_instance_num="$SAP_INSTANCE_NUM" -v sap_host_name="$SAP_HOST_NAME" '{gsub("<SAP_SID>", sap_sid); gsub("<SAP_HOST_NAME>", sap_host_name); gsub("<SAP_INSTANCE_NUM>", sap_instance_num);}1' /tmp/sid_config_template.txt > ${SAP_SID}_configfile
temp=`awk -v sap_adm_pw="$SAP_ADM_PW" -v sid_adm_pw="$SID_ADM_PW" -v system_pw="$SYSTEM_PW" '{gsub("<SAP_ADM_PW>", sap_adm_pw); gsub("<SID_ADM_PW>", sid_adm_pw); gsub("<SYSTEM_PW>", system_pw);}1' /tmp/sid_passwords_template.txt`
# Pass the configs into the HANA install
echo $temp | ./hdblcm --batch --action=install --configfile=${SAP_SID}_configfile --read_password_from_stdin=xml
