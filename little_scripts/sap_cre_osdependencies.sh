#!/bin/bash
# What should this script do and check
# Determine if it's PAYG or BYOS, OS type --> done
# OS parameters (SAP notes) are not to be set as they change too much
# saptune/sapconf/tuned --> done, sapconf
# check IO scheduler  
# check and print filesystems, strip size, striping, disks used
# OS kernel version --> just use uname -r
# OS type  --> done, version and payg/byos
# firewalld/selinux --> done
# transparent huge pages --> done
# numa balancing --> done
# create swap --> done
# check for ADE encryption (no easy swap)  
# 
# needs to work 


is_curl_installed () {
        if ! hash curl 2>/dev/null ; then
                logfunc.logError "Curl is not installed"
                logfunc.exit 1 "Please install curl from your OS update repositories and re-run this script again"
        fi
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
}

run_sapconf () 
{
        run_sapconf.installed ()
        {
               if [ -f /etc/sysconfig/sapconf ]; then
                        logfunc.logPass "Sapconf is installed on this VM"
                else
                        logfunc.logWarn "Sapconf is NOT installed on this VM"
                        [ echo $os_offer | grep -iq "sles-sap" ] || logfunc.logWarn "OS is NOT build on SLES-SAP offer and does not offer sapconf"
                fi
        }

        if [ $os_vendor == "sles" ]; then
                run_sapconf.installed && sudo systemctl restart sapconf
        fi
}

check_uuidd ()
{
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
        transp_hugepages=$(cat /sys/kernel/mm/transparent_hugepage/enabled | grep -Po '\[\K[^]]*')
        [ $transp_hugepages == 'never' ] && logfunc.logPass "Transparent hugepages are correctly set to" $transp_hugepages || logfunc.logError "Transparent hugepages are incorrectly set to " ${transp_hugepages}", correct value is never"
}


check_numa_balancing () 
{
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
                        logfunc.logInfo "Setting swap"
                        logfunc.logPass "Resource disk is mounted"
                resource_disk_mb=$(df -m /mnt/resource | grep resource | awk '{printf $2}')
                        logfunc.logInfo "Resource disk on this VM has" "${resource_disk_mb}" "MiB size"
                sudo sed -i '/ResourceDisk.EnableSwap=n/ c\ResourceDisk.EnableSwap=y' /etc/waagent.conf
                ideal_swap_size=$(( vm_mem_mb / 2 > 20480 ? 20480 : vm_mem_mb /2 ))
                ideal_swap_size=$(( $ideal_swap_size > $resource_disk_mb ? $resource_disk_mb - 2048 : ideal_swap_size ))
                        logfunc.logInfo "Setting swap size in /etc/waagent.conf to" ${ideal_swap_size} "MiB"
                sudo sed -i '/ResourceDisk.SwapSizeMB=/ c\ResourceDisk.SwapSizeMB='$ideal_swap_size /etc/waagent.conf
                        logfunc.logInfo "Restarting WAagent to activate swap"
                sudo systemctl restart waagent
                sleep 1
                active_swap_size=$(( $(free | awk '/^Swap:/ { printf $2 }') / 1024 ))
                        logfunc.logInfo "Swapsize now active with size "${active_swap_size}" MiB"
        else   
                logfunc.logError "Resource disk is not mounted"
                logfunc.logError "Check /var/log/waagent.log why resource disk is missing"
                logfunc.logError "/etc/waagent.conf might contain ResourceDisk.Format=n"
                logfunc.exit 1 "Resource disk is missing"
        fi
               
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
        is_curl_installed  # done
        get_os_type_and_version # done
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
main