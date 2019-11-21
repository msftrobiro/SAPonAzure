#!/bin/bash
# script requires two parameters and runs as root

function display_usage(){
    echo "Usage:"
    echo "Execute script as root only! Two parameters required."
    echo "First parameter: SAP SID (in case of HANA, SID of HANA instance, not the SAP SID)"
    echo "Second parameter: the chosen operation - stop|start|status"
    echo "Example: stopstartsap.sh SHQ stop"
}

function start_hana(){


}

function stop_hana(){


}

function start_abap(){


}

function stop_abap(){


}

function get_instance_no(){


}





#end of function declaration, go to work
if [[ ( $@ == "-usage") ||  $@ == "-h"  ||  $@ == "-help" ||  $@ == "-?"  || $@ == "--help" ]]
    then
        display_usage
        exit 0
fi

# check for arguments
if [[ $# -le 1 ]]
then
    display_usage
    exit 1
fi

# root check
if [[ $EUID -ne 0 ]]
then
    echo "Script must be executed as root!"
    echo "See usage details with --help"
    exit 1
fi

