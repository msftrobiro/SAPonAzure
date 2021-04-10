#!/bin/bash

#########################################################################
# Helper utilities
#
# Acknowledgements: Fergal Mc Carthy, SUSE
#########################################################################

function save_config_var() {
    local var_name="${1}" var_file="${2}"
    
    sed -i /${var_name}/d "${var_file}"
    echo "${var_name}=${!var_name}" >> "${var_file}"
}

function save_config_vars() {
    local var_file="${1}" var_name
    
    shift  # shift params 1 place to remove var_file value from front of list
    
    for var_name  # iterate over function params
    do
        sed -i /${var_name}/d "${var_file}"
        echo "${var_name}=${!var_name}" >> "${var_file}"
    done
}

function load_config_vars() {
    local var_file="${1}" var_name var_value
    
    for var_name
    do
        var_value="$(grep -m1 "^${var_name}" "${var_file}" | cut -d'=' -f2 | tr -d '"')"
        
        [ -z "${var_value}" ] && continue
        
        typeset -g "${var_name}"  # declare the specified variable as global
        
        eval "${var_name}='${var_value}'"  # set the variable in global context
    done
}


function init() {
    local automation_config_directory="${1}"
    local generic_config_information="${2}"
    app_config_information="${3}"
    
    if [ ! -d "${automation_config_directory}" ]
    then
        # No configuration directory exists
        mkdir "${automation_config_directory}"
        touch "${app_config_information}"
        touch "${generic_config_information}"
        if [ -n "${DEPLOYMENT_REPO_PATH}" ]; then
            # Store repo path in ~/.sap_deployment_automation/config
            save_config_var "DEPLOYMENT_REPO_PATH" "${generic_config_information}"
            config_stored=true
        fi
        if [ -n "$ARM_SUBSCRIPTION_ID" ]; then
            # Store ARM Subscription info in ~/.sap_deployment_automation
            save_config_var "ARM_SUBSCRIPTION_ID" "${app_config_information}"
            arm_config_stored=true
        fi
        
    else
        touch "${generic_config_information}"
        load_config_vars ${generic_config_information} "DEPLOYMENT_REPO_PATH"
    fi
    
    
}