#!/bin/bash

function showhelp {
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo "#                                                                                       #" 
    echo "#   This file contains the logic to addd the SPN secrets to the keyvault.               #" 
    echo "#                                                                                       #" 
    echo "#                                                                                       #" 
    echo "#   Usage: set_secret.sh                                                                #"
    echo "#      -e environment name                                                              #"
    echo "#      -v vault name                                                                    #"
    echo "#      -c SPN app id                                                                    #"
    echo "#      -s SPN password                                                                  #"
    echo "#      -t tenant of                                                                     #"
    echo "#      -i true/false. If true runs in interactive mode prompting for input              #"
    echo "#      -h Show help                                                                     #"
    echo "#                                                                                       #" 
    echo "#   Example:                                                                            #" 
    echo "#                                                                                       #" 
    echo "#   [REPO-ROOT]deploy/scripts/set_secret.sh \                                           #"
	echo "#      -e PROD  \                                                                       #"
	echo "#      -v prodweeuusrabc  \                                                             #"
	echo "#      -c 11111111-1111-1111-1111-111111111111 \                                        #"
	echo "#      -s SECRETPassword \                                                              #" 
	echo "#      -t 222222222-2222-2222-2222-222222222222                                         #"
    echo "#                                                                                       #" 
    echo "#########################################################################################"
}


while getopts ":e:c:s:t:h:v:x:d:i" option; do
    case "${option}" in
        e) environment=${OPTARG};;
        c) client_id=${OPTARG};;
        s) client_secret=${OPTARG};;
        t) tenant=${OPTARG};;
        v) vaultname=${OPTARG};;
        i) interactive=true;;
        d) deployer_paramfile=${OPTARG};;
        h) showhelp
           exit 0
           ;;
        ?) echo "Invalid option: -${OPTARG}."
           exit 0
           ;; 
            
    esac
done

if [ -n "$deployer_paramfile" ]; then
    key=$(echo "$deployer_paramfile" | cut -d. -f1)
    automation_config_directory=~/.sap_deployment_automation/
    deployer_config_information="${automation_config_directory}""${key}"
    if [ ! -d "${automation_config_directory}" ]
    then
        # No configuration directory exists
        mkdir "${automation_config_directory}"
    else
        temp=$(grep "Environment" "${deployer_config_information}")
        if [ ! -z "${temp}" ]
        then
            environment=$(echo "${temp}" | cut -d= -f2)
            environment_exists=1
        else
            environment_exists=0
        fi
        
        temp=$(grep "keyvault" "${deployer_config_information}")
        if [ ! -z "${temp}" ]
        then
            vaultname=$(echo "${temp}" | cut -d= -f2)
            vaultname_exists=1
        else
            vaultname_exists=0
        fi
        
        temp=$(grep "SPNAppID" "${deployer_config_information}")
        if [ ! -z "${temp}" ]
        then
            client_id=$(echo "${temp}" | cut -d= -f2)
            client_id_exists=1
        else
            client_id_exists=0
        fi
        
        temp=$(grep "Tenant" "${deployer_config_information}")
        if [ ! -z "${temp}" ]
        then
            tenant=$(echo "${temp}" | cut -d= -f2)
            tenant_exists=1
        else
            tenant_exists=0
        fi
    fi
fi


if [ $interactive == true ]; then
    if [ ! -n "${environment}" ]; then
        read -p "Environment name:"  environment
    fi

    if [ ! -n "$vaultname" ]; then
        read -p "Keyvault name:"  vaultname
    fi 

    if [ ! -n "$client_id" ]; then
        read -p "SPN App ID:"  client_id
    fi 

    read -p "SPN App Password:"  client_secret
    
    if [ ! -n "${tenant}" ]; then
        read -p "SPN Tenant ID:"  tenant
    fi 
        
fi

if [ ! -n "{$ARM_SUBSCRIPTION_ID}" ]; then
    echo ""
    echo "####################################################################################"
    echo "# Missing environment variables (ARM_SUBSCRIPTION_ID)!!!                           #"
    echo "# Please export the folloing variables:                                            #"
    echo "# ARM_SUBSCRIPTION_ID (subscription containing the state file storage account)     #"
    echo "####################################################################################"
    exit 1
fi

if [ ! -n "${environment}" ]; then
    showhelp
    exit -1
fi

if [ ! -n "${vaultname}" ]; then
    showhelp
    exit -1
fi

if [ ! -n "${client_id}" ]; then
    showhelp
    exit -1
fi

if [ ! -n "$client_secret" ]; then
    showhelp
    exit -1
fi

if [ ! -n "${tenant}" ]; then
    showhelp
    exit -1
fi

echo "#########################################################################################"
echo "#                                                                                       #" 
echo "#                              Setting the secrets                                      #"
echo "#                                                                                       #" 
echo "#########################################################################################"
echo ""

if [ $environment_exists  -eq 0 ]
    then
    sed -i /Environment/d  "${deployer_config_information}"
    echo "Environment=${environment} >> ${deployer_config_information}"
fi

if [ $vaultname_exists -eq 0 ]
    then
    sed -i /keyvault/d  "{$deployer_config_information}"
    echo "keyvault=${vaultname}" >> ${deployer_config_information}
fi

if [ $client_id_exists -eq 0 ]
    then
    sed -i /SPNAppID/d  "{$deployer_config_information}"
    echo "SPNAppID=${client_id}" >> ${deployer_config_information}
fi

if [ $tenant_exists -eq 0 ]
    then
    sed -i /Tenant/d  "{$deployer_config_information}"
    echo "Tenant=${tenant}" >> ${deployer_config_information}
fi

result=$(az keyvault secret set --name "${environment}-subscription-id" --vault-name "${vaultname}" --value $ARM_SUBSCRIPTION_ID | grep "The user, group or application")

if [ ! -n $result ]; then 
    echo "#########################################################################################"
    echo "#                                                                                       #" 
    echo "#          No access to add the secrets in the" "${vaultname}" "keyvault            #"
    echo "#            Please add an access policy for your account you use                       #" 
    echo "#                                                                                       #" 
    echo "#########################################################################################"
    echo ""
    exit -1
fi


az keyvault secret set --name "${environment}-client-id"       --vault-name "${vaultname}" --value $client_id
az keyvault secret set --name "${environment}-client-secret"   --vault-name "${vaultname}" --value $client_secret
az keyvault secret set --name "${environment}-tenant-id"       --vault-name "${vaultname}" --value $tenant
