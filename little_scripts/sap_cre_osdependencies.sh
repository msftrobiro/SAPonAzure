#!/bin/bash
# What should this script do and check
# Determine if it's PAYG or BYOS, OS type
# OS parameters (SAP notes) are not to be set as they change too much
# saptune/sapconf/tuned
# check IO scheduler
# check and print filesystems, strip size, striping, disks used
# OS kernel version
# OS type
# transparent huge pages
# numa balancing
# create swap
# check for ADE encryption (no easy swap)
# etc etc I didn't think of yet, work in progress, duh
# 
# needs to work 


is_curl_installed () {
        if ! hash curl 2>/dev/null ; then
                echo "ERROR: curl is not installed"
                echo "Please install curl from your OS update repositories and re-run this script again"
                exit 1
}

is_os_byos () {
        curl_os_offer=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/storageProfile?api-version=2019-06-01" |grep -Po '"offer":.*?[^\\]"')
        if echo $curl_os_offer | grep -iq byos; then 
                os_byos=true
        else 
                os_byos=false
        fi
}

os_type_and_version () {
        os_pretty_name=$(hostnamectl |grep "Operating System" | cut -d ":" -f2 | cut -d "(" -f1)
        if echo $os_pretty_name | grep "Red Hat Enterprise Linux"; then
                os_name=rhel
        elif echo $os_pretty_name | grep "SUSE Linux Enterprise"; then
                os_name=sles
        else
                os_name="ERROR - not RHEL nor SLES"
        fi
        echo $os_name
        os_version=$(grep VERSION_ID /etc/os-release | cut -d "\"" -f2)
}

