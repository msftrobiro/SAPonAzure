#!/bin/bash
# What should this script do and check
# Determine if it's PAYG or BYOS, OS type --> done
# OS parameters (SAP notes) are not to be set as they change too much
# saptune/sapconf/tuned --> done, sapconf
# check IO scheduler  
# OS kernel version --> done
# OS type  --> done, version and payg/byos
# firewalld/selinux --> done
# transparent huge pages --> done
# numa balancing --> done
# create swap --> done
# check for ADE encryption (no easy swap)  
#
# Usage:
# Script expects to run by either root directly or by a user which can sudo without prompted for password


is_curl_installed () 
{
        if ! hash curl 2>/dev/null ; then
                logfunc.logError "Curl is not installed"
                logfunc.exit 1 "Please install curl from your OS update repositories and re-run this script again"
        fi
}

display_usage () 
{
        logfunc.logInfo "########################################################################################################"
        logfunc.logInfo "Correct usage - script needs to run by either root direct or user which can sudo without password prompt"
        logfunc.logInfo "No parameters are needed or expected for typical usage"
        logfunc.logInfo "Optional parameters are: "
        logfunc.logInfo "-o <path+filename> to save output to a file"
        logfunc.logInfo "--no-swap to only print but not change OS swap file size"
        logfunc.logInfo "########################################################################################################"
}


check_io_scheduler ()
{
        check_io_scheduler.disk_type ()
        {
                disk_type_scsi_info=$(lsblk /dev/${1} -nd -o hctl)
                case $(echo $disk_type_scsi_info | cut -d: -f3,4) in 
                        "0:0")
                                disk_type="OS root"
                                ;;
                        "1:0")
                                disk_type="OS resource disk"
                                ;;
                        *)
                                disk_type="Data disk"
                                ;;
                esac
        }

                logfunc.logInfo "Listing IO scheduler info for all disks"
                scheduler_details=0
                disk_type=0
                azure_lun=0
        for i in $(lsblk -I 8 -nd -o name)
        do
                scheduler_details=$(cat /sys/block/${i}/queue/scheduler | grep -Po '\[\K[^]]*')
                check_io_scheduler.disk_type $i 
                [[ $disk_type == 'Data disk' ]] && azure_lun=$(lsblk /dev/${i} -nd -o hctl | cut -d: -f4)
                [[ $disk_type == 'Data disk' ]] && logfunc.logInfo "/dev/"${i} " :" $disk_type ":  Azure LUN="${azure_lun} ":  OS I/O scheduler in use="${scheduler_details}
                [[ $disk_type == OS* ]] && logfunc.logInfo "/dev/"${i} " :" $disk_type ":  OS I/O scheduler in use="${scheduler_details}
        done
}


get_os_type_and_version () 
{
        os_offer=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/storageProfile?api-version=2019-06-01" |grep -Po '"offer":.*?[^\\]"')
        echo $os_offer | grep -iq byos && os_byos=true || os_byos=false        
        os_pretty_name=$(hostnamectl |grep "Operating System" | cut -d ":" -f2 | cut -d "(" -f1)
        if (echo $os_pretty_name | grep -q "Red Hat Enterprise Linux"); then
                os_vendor=rhel
        elif (echo $os_pretty_name | grep -q "SUSE Linux Enterprise"); then
                os_vendor=sles
        else
                os_vendor="ERROR - not RHEL nor SLES"
        fi

        case $(echo ${os_offer} | tr a-z A-Z) in
                *"RHEL-SAP-HA"*)
                        os_azure_image_offer=RHEL-SAP-HA
                        ;;
                *"RHEL-SAP"*)
                        os_azure_image_offer=RHEL-SAP
                        ;;
                *"RHEL"*)
                        os_azure_image_offer=RHEL
                        ;;
                *"SLES-SAP"*)
                        os_azure_image_offer=SLES-SAP
                        ;;
                *"SLES"*)
                        os_azure_image_offer=SLES
                        ;;
                *)
                        logfunc.logError "Could not determine Azure OS image offer used by this VM"
                        logfunc.exit 1 "Check value of OS image offer in VM metadata for support OS - RHEL or SLES"
                        ;;                              
        esac
        os_version=$(grep VERSION_ID /etc/os-release | cut -d "\"" -f2)    

        logfunc.logInfo "OS information:" $os_pretty_name
        logfunc.logInfo "OS_NAME VERSION:" $os_azure_image_offer $os_version
        logfunc.logInfo "OS_KERNEL_VERSION:" $(uname -r)
}

run_sapconf () 
{
        run_sapconf.installed ()
        {
               if [ -f /etc/sysconfig/sapconf ]; then
                        logfunc.logPass "Sapconf is installed on this VM, executing"
                        sapconf_installed=y
                else
                        logfunc.logWarn "Sapconf is NOT installed on this VM"
                        echo $os_offer | grep -iq "sles-sap"  || logfunc.logWarn "OS is NOT build on SLES-SAP offer and does not offer sapconf"
                        sapconf_installed=n
                fi
        }

        if [ $os_vendor == "sles" ]; then
                logfunc.logInfo "Checking for sapconf status and executing if installed"
                run_sapconf.installed
                [ $sapconf_installed == 'y' ] && sudo systemctl restart sapconf
        fi
}

check_uuidd ()
{
                logfunc.logInfo "Checking for UUIDD status"
        if [ $(sudo systemctl show -p ActiveState uuidd | cut -d '=' -f2) == 'inactive' ] && [ $(sudo systemctl show -p SubState uuidd | cut -d '=' -f2) == 'dead' ]; then
                logfunc.logError "UUIDD is not active"
                uuidd_active=n
        elif [ $(sudo systemctl show -p ActiveState uuidd | cut -d '=' -f2) == 'active' ] && [ $(sudo systemctl show -p SubState uuidd | cut -d '=' -f2) == 'running' ]; then
                logfunc.logPass "UUIDD is active and running"
                uuid_active=y
        else   
                logfunc.logWarn "Could not determine UUIDD service status"
                uuidd_active=errorstate
        fi
}

check_transparent_hugepages () 
{
                logfunc.logInfo "Checking for transparent hugepages setting"
        transp_hugepages=$(cat /sys/kernel/mm/transparent_hugepage/enabled | grep -Po '\[\K[^]]*')
        if [ $transp_hugepages == 'never' ]; then
                logfunc.logPass "Transparent hugepages are correctly set to" $transp_hugepages
        else
                logfunc.logError "Transparent hugepages are incorrectly set to " ${transp_hugepages}", correct value is never"
                logfunc.logInfo "Setting value to never for current boot"
                echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled 1>/dev/null
                logfunc.logWarn "Setting permanent setting for transparaent hugepages to never"
                sudo grub2-editenv - set "transparent_hugepage=never"
        fi
}


check_numa_balancing () 
{
                logfunc.logInfo "Checking for NUMA balancing"
        numa_balancing=$(cat /proc/sys/kernel/numa_balancing)
        [ $numa_balancing == '0' ] && logfunc.logPass "NUMA balancing is turned off" || logfunc.logError "NUMA balancing is enabled, must be turned off"
}


check_for_ade () 
{
                logfunc.logInfo "Checking for Azure Disk Encryption usage"
        # dunno how, yet
}


check_firewalld ()
{
                logfunc.logInfo "Checking for Firewall status"
        if [ $(sudo systemctl show -p ActiveState firewalld | cut -d '=' -f2) == 'inactive' ] && [ $(sudo systemctl show -p SubState firewalld | cut -d '=' -f2) == 'dead' ]; then
                logfunc.logPass "OS Firewall daemon is not active"
                os_firewall_active=n
        elif [ $(sudo systemctl show -p ActiveState firewalld | cut -d '=' -f2) == 'active' ] && [ $(sudo systemctl show -p SubState firewalld | cut -d '=' -f2) == 'running' ]; then
                logfunc.logWarn "OS Firewall daemon is active, check rules and consider if better to disable"
                os_firewall_active=y
        else   
                logfunc.logWarn "OS Firewall daemon could not determine state. Check firewalld status"
                os_firewall_active=errorstate
        fi
}

check_selinux () 
{
                logfunc.logInfo "Checking for SELinux status"
        hash getenforce 2>/dev/null && selinux_binaries=y || selinux_binaries=n
        selinux_enforcement=empty      
        [ $selinux_binaries == "y" ] && selinux_enforcement=$(getenforce)
        [ $selinux_binaries == "n" ] && logfunc.logPass "SELinux is disabled"
        [ $selinux_enforcement == "Disabled" ] && logfunc.logPass "SELinux is installed but is" $selinux_enforcement
        if [ $selinux_enforcement == "Permissive" ] || [ $selinux_enforcement == "Enforcing" ]; then
                logfunc.logWarn "SELinux is installed and is set to status" $selinux_enforcement 
                [ $selinux_enforcement == "Enforcing" ] && logfunc.logInfo "Setting SELinux temporarily first to Permissive state" && sudo setenforce Permissive
                logfunc.logInfo "Disabling SELinux permanently"
                sudo sed -i '/^#/!s/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
                logfunc.logWarn "Reboot required to fully disable SELinux, currently still set to Permissive mode"
        fi
}


set_swap () 
{
        vm_mem_mb=$(( $(cat /proc/meminfo | grep MemTotal | awk '{printf $2 }') / 1024 ))
        if $(mountpoint /mnt/resource -q); then
                logfunc.logInfo "Setting up swap"
                logfunc.logPass "Resource disk is mounted"
                resource_disk_mb=$(df -m /mnt/resource | grep resource | awk '{printf $2}')
                logfunc.logInfo "Resource disk on this VM has" $resource_disk_mb "MiB size"
                sudo sed -i '/ResourceDisk.EnableSwap=n/ c\ResourceDisk.EnableSwap=y' /etc/waagent.conf
                ideal_swap_size=$(( vm_mem_mb / 2 > 20480 ? 20480 : vm_mem_mb /2 ))
                ideal_swap_size=$(( $ideal_swap_size > $resource_disk_mb ? $resource_disk_mb - 2048 : ideal_swap_size ))
                if [ $doNotChangeSwap == 'y' ]; then
                        logfunc.logInfo "Parameter to not touch swap is set, no further swap changes"
                        logfunc.logInfo "Current swap size" $(( $(cat /proc/meminfo | grep SwapTotal | awk '{printf $2 }') / 1024 )) "MiB"
                else 
                        logfunc.logInfo "Setting swap size in /etc/waagent.conf to" $ideal_swap_size "MiB"
                        sudo sed -i '/ResourceDisk.SwapSizeMB=/ c\ResourceDisk.SwapSizeMB='$ideal_swap_size /etc/waagent.conf
                        logfunc.logInfo "Restarting WAagent to activate swap"
                        sudo systemctl restart waagent
                        sleep 1
                        active_swap_size=$(( $(free | awk '/^Swap:/ { printf $2 }') / 1024 ))
                        logfunc.logInfo "Swapsize now active with size " $active_swap_size "MiB"
                fi
        else   
                logfunc.logError "Resource disk is not mounted"
                logfunc.logError "Check /var/log/waagent.log why resource disk is missing"
                logfunc.logError "/etc/waagent.conf might contain ResourceDisk.Format=n"
                logfunc.exit 1 "Resource disk is missing"
        fi
               
}


parse_script_options ()
{
        while [ $# -gt 0 ]
        do
                case $1 in 
                        "-h" | "-help" | "--help" | "-?")
                                shift
                                display_usage
                                logfunc.exit 0 "Exiting script"
                                ;;
                        "-o")
                                shift
                                useLogfile=y
                                shift
                                logFileLocation=$1
                                ;;
                        "--no-swap")
                                shift
                                doNotChangeSwap=y
                                ;;
                        *)
                                logfunc.exit 1 "Unknown parameter supplied. Use -h to display usage."
                esac
        done
}


logfunc () 
{

        {
                if [[ useLogfile == "y" ]];
                then 
                        touch /tmp/${logFileLocation}
                        exec 3> "/tmp/${logFileLocation}"
                else   
                        exec 3> "/dev/null"
                fi
        }

        logfunc.logWrite()
        {
                echo -e "${1}[$(date -Iseconds)] ${@:2}\e[0m" 
                echo -e "${1}[$(date -Iseconds)] ${@:2}\e[0m" &>3
        }

        logfunc.logInfo() 
        {
                logfunc.logWrite "\e[1;37m" "[INFO]" "${@}"
        }

        logfunc.logPass() 
        {
                logfunc.logWrite "\e[1;32m" "[PASS]" "${@}"
        }

        logfunc.logWarn() 
        {
                logfunc.logWrite "\e[1;33m" "[WARN]" "${@}"
        }

        logfunc.logError() 
        {
                logfunc.logWrite "\e[1;31m" "[ERRO]" "${@}"
        }

        logfunc.exit()
        {
                if [[ $# == 0 ]]; then
                exec 3>&-
                exit 0
                fi

                if [ $1 -eq 0 ]; then
                logfunc.logWrite "\e[1;36m" "[SUCC]" $2
                else
                logfunc.logWrite "\e[1;31m" "[FAIL]" "Script failed, exiting with received errno" $1 "from previous operation"
                logfunc.logWrite "\e[1;31m" "[FAIL]" $2
                fi

                exec 3>&-
                exit $1
        }
}

main() 
{
        logfunc # done, can add file logger
        parse_script_options "$@" # done
        is_curl_installed  # done
        get_os_type_and_version # done
        check_io_scheduler # done, no lvm info yet
        set_swap # done
        check_firewalld # done
        check_selinux # done
        run_sapconf # done
        check_uuidd # done
        check_transparent_hugepages # done, check only
        check_numa_balancing # done, check only
        check_for_ade ### unfinished
        
        logfunc.exit 0 "Script finished successfully"
}

# end function declarations
main "$@"