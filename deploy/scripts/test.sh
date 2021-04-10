#!/bin/bash

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

load_config_vars ~/.sap_deployment_automation/config DEPLOYMENT_REPO_PATH
echo $DEPLOYMENT_REPO_PATaH

