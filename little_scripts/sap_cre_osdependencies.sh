#!/bin/bash
# What should this script do and check
# Determine if it's PAYG or BYOS
# OS parameters (SAP notes)
# saptune
# check and print filesystems, strip size, striping, disks used
# etc etc I didn't think of yet, work in progress, duh
# 


is_curl_installed () {
        if ! hash curl 2>/dev/null ; then
                echo "ERROR: curl is not installed"
                echo "Please install curl from your OS update repositories and re-run this script again"
                exit 1
}


