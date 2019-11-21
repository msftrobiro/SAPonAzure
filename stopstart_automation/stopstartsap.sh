#!/bin/bash
# script requires two parameters and runs as root

function display_usage(){
    echo "Usage:"
    echo "Execute script as root only! Upto four parameters, three are required."
    echo "First parameter: SAP SID (in case of HANA, SID of HANA instance, not the SAP SID)"
    echo "Second parameter: the chosen operation - stop|start|status"
    echo "Third parameter: SAP system type - ascs|appserver|hana|ase"
    echo "Fourth parameter: SAP/HANA instance number"
    echo "Example: stopstartsap.sh SHQ stop ascs 00"
}

function start_hana(){
    echo "start_hana function"
}

function stop_hana(){
    echo "stop_hana function"
}

function start_abap(){
    if [[ ! -z $3 ]]; then missing_instno; fi
    su - ${SAPSIDLOWER}adm -c "sapcontrol -nr $INSTNO -prot NI_HTTP -function StopService"
}

function stop_abap(){
    if [[ ! -z $3 ]]; then missing_instno; fi
}

function status_abap(){
    if [[ ! -z $3 ]]; then missing_instno; fi
}

function status_hana(){
    echo "status_hana function"
}

function missing_instno(){
    echo "Missing SAP instance number!"
    echo "Please see usage, fourth parameter required with instance number"
    exit 1
}


#end of function declaration, go to work
if [[ $1 == "-usage" ||  $1 == "-h"  ||  $1 == "-help" ||  $1 == "-?"  || $1 == "--help" ]]
    then
        display_usage
        exit 0
fi


# root check
if [[ $EUID -ne 0 ]]
then
    echo "Script must be executed as root!"
    echo "See usage details with --help"
    exit 1
fi

# check for coirect arguments
if [[ $# -le 2 ]]
then
    display_usage
    exit 1
fi

SAPSID=$1
if [[ `echo ${#SAPSID}` -ne 3 ]]
then 
    echo "SAP SID has incorrect length, must be 3 characters"
    exit 1
fi

OP=`echo "$2" | awk '{print tolower($0)}'`
if [[ $OP != "stop" && "$OP" != "start" && "$OP" != "status" ]]
then   
    echo "Invalid operation specified"
    echo "Valid values are stop, start or status"
    exit 1
fi

SAPTYPE=`echo "$3" | awk '{print tolower($0)}'`
if [[ $SAPTYPE != "ascs" && $SAPTYPE != "appserver" && $SAPTYPE != "hana" && $SAPTYPE != "ase" ]]
then
    echo "Invalid SAP system type specified"
    echo "Valid values are ascs, appserver, hana, ase"
    exit
fi

if [[ ! -z $4 ]] && [[ `echo ${#4}` -ne 2 ]]
then
    echo "Invalid SAP/HANA number specified, must be 2 digit integer"
    exit 1
else
    INSTNO=$4
fi

SAPSIDLOWER=`echo "$SAPSID" | awk '{print tolower($0)}'`
if [[ $OP == "stop" && ( $SAPTYPE == "ascs" || $SAPTYPE == "appserver" ) ]]; then stop_abap; fi
if [[ $OP == "start" && ( $SAPTYPE == "ascs" || $SAPTYPE == "appserver" ) ]]; then  start_abap; fi
if [[ $OP == "status" && ( $SAPTYPE == "ascs" || $SAPTYPE == "appserver") ]]; then  status_abap; fi
#if [[ $SAPTYPE == "appserver" && $OP == "stop" ]]; then   stop_abap; fi
#if [[ $SAPTYPE == "appserver" && $OP == "start" ]]; then  status_abap; fi
if [[ $OP == "stop" && $SAPTYPE == "hana" ]]; then  stop_hana; fi
if [[ $OP == "start" && $SAPTYPE == "hana" ]]; then  start_hana; fi
if [[ $OP == "status" && $SAPTYPE == "hana" ]]; then  status_hana; fi
if [[ $OP == "stop"  && $SAPTYPE == "ase" ]]; then  echo "ase not supported yet"; fi
if [[ $OP == "start" && $SAPTYPE == "ase" ]]; then  echo "ase not supported yet"; fi
if [[ $OP == "status" && $SAPTYPE == "ase" ]]; then  echo "ase not supported yet"; fi

echo "end of script"