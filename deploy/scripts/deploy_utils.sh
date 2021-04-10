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
        var_value="$(grep -m1 "^${var_name)=" "${var_file}" | cut -d'=' -f2 | tr -d '"')"

        [ -z "${var_value}" ] && continue

        typeset -g "${var_name}"  # declare the specified variable as global

        eval "${var_name}='${var_value}'"  # set the variable in global context
    done
}
