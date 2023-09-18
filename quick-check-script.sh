LogFile=/tmp/check-script.txt
[ -e $LogFile ] && rm $LogFile

HelpOutput()
{ 
  echo "The script doesn't require any parameters for non-clustered systems"
  echo "For clustered systems running pacemaker, add the role"
  echo "For ASCS, use ASCS keyword"
  echo "For clustered DB, use DB keyword"
  echo "Syntax is case sensitive"
  echo "Again, for non-clustered VMs, including databases, no keyword is needed"
  echo "Examples:"
  echo "   ordinary application server: script.sh"
  echo "   ordinary ASCS or DB VM, non-clustered: script.sh"
  echo "   clustered ASCS VM, either one of them: script.sh -a"
  echo "   clustered DB VM, either VM:            script.sh -d"
  echo "   bring up this helpful text:            script -h"
}

while getopts ":had" option; do
  case $option in
    h) HelpOutput; exit 0;;
    a) ASCS=1;;
    d) DB=1;;
    ?) echo "Error: Invalid option" $option "provided"; exit 1;;
  esac
done

# IC-0001
echo "### IC-0001 Hostname" >> $LogFile
/bin/hostname >> $LogFile

# IC-0002
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-0002 Kernel info" >> $LogFile
/bin/uname -r >> $LogFile

# IC-0003
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-0003 Azure Hypervisor Host" >> $LogFile
/bin/cat /var/lib/hyperv/.kvp_pool_3 | tr -d '\\000' | grep -o -P '(?<=HostName).*(?=HostingSystemEditionId)' >> $LogFile

# IC-0004
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-0004 VM Type" >> $LogFile
/usr/bin/curl -s --noproxy '*' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2019-11-01&format=text' >> $LogFile

# IC-0005
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-0005 Availability Zone" >> $LogFile
/usr/bin/curl -s --noproxy '*' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/zone?api-version=2021-03-01&format=text' >> $LogFile

# IC-0006
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-0006 Availability Set" >> $LogFile
echo "Not implemented" >> $LogFile

# IC-0007
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-0007 OS release" >> $LogFile
/bin/cat /etc/os-release >> $LogFile

# IC-0008
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-0008 OS release" >> $LogFile
echo "Not implemented" >> $LogFile

# IC-0009
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-0009 PPG" >> $LogFile
echo "Not implemented" >> $LogFile

# IC-0010
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-0010 PPG VMs associated" >> $LogFile
echo "Not implemented" >> $LogFile

# IC-0011
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-0011 VM Gen" >> $LogFile
echo "Not implemented" >> $LogFile

# IC-9002
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9002 All sysctl params" >> $LogFile
sudo /sbin/sysctl -a >> $LogFile

# IC-9003
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9003 Get fstab" >> $LogFile
sudo /bin/cat /etc/fstab >> $LogFile

# IC-9004
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9004 Get systemctl" >> $LogFile
sudo /bin/systemctl list-unit-files --state=enabled >> $LogFile

# IC-9005
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9005 Get chkconfig" >> $LogFile
sudo /sbin/chkconfig 2> /dev/null >> $LogFile

# IC-9006
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9006 Get installed packages" >> $LogFile
rpm -qa >> $LogFile

# IC-9007
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9007 SBD Config" >> $LogFile
sudo /bin/cat /etc/sysconfig/sbd >> $LogFile

# IC-9008
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9008 Pacameker Config" >> $LogFile
sudo /usr/sbin/crm configure show >> $LogFile

# IC-9009
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9009 Pacemaker status" >> $LogFile
sudo /usr/sbin/crm status >> $LogFile

# IC-9012
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9012 lsscsi output" >> $LogFile
sudo /usr/bin/lsscsi >> $LogFile

# IC-9013
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9013 Storage metadata" >> $LogFile
/usr/bin/curl -s --noproxy '*' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/storageProfile?api-version=2021-12-13' >> $LogFile

# IC-9015
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9015 lvm fullreport" >> $LogFile
sudo /sbin/lvm fullreport --reportformat json >> $LogFile

# IC-9015
echo "### --------------------------------------------------" >> $LogFile
echo "### IC-9016 mounted fs" >> $LogFile
df -h >> $LogFile

# start checks sections
echo "### --------------------------------------------------" >> $LogFile
echo "### START CHECKS SECTION ###" >> $LogFile

if [ "$DB" = "1" ]; then
  # ASCS-NET-0001
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-NET-0001 Load Balancer timestamps" >> $LogFile
  sudo /sbin/sysctl net.ipv4.tcp_timestamps -n >> $LogFile

  # HDB-HA-SLE-0001
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0001 SAP HANA Automatic Site Takeover" >> $LogFile
  sudo /usr/sbin/crm configure show | grep 'PREFER_SITE_TAKEOVER=true' >> $LogFile

  # HDB-HA-SLE-0002
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0002 SAP HANA Automated Register" >> $LogFile
  sudo /usr/sbin/crm configure show | grep 'AUTOMATED_REGISTER=true' >> $LogFile

  # HDB-HA-SLE-0003
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0003 Pacemaker Stonith enabled" >> $LogFile
  sudo /usr/sbin/crm configure show | grep 'stonith-enabled=true' >> $LogFile

  # HDB-HA-SLE-0004
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0004 Pacemaker Stonith timeout" >> $LogFile
  sudo /usr/sbin/crm configure show | grep 'stonith-timeout' >> $LogFile

  # HDB-HA-SLE-0005
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0005 Pacemaker corosync token" >> $LogFile
  sudo /usr/sbin/crm corosync get totem.token >> $LogFile

  # HDB-HA-SLE-0006
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0006 Pacemaker totem.token_retransmits_before_loss_const" >> $LogFile
  sudo /usr/sbin/crm corosync get totem.token_retransmits_before_loss_const >> $LogFile

  # HDB-HA-SLE-0007
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0007 Pacemaker corosync join" >> $LogFile
  sudo /usr/sbin/crm corosync get totem.join >> $LogFile

  # HDB-HA-SLE-0008
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0008 Pacemaker corosync consensus" >> $LogFile
  sudo /usr/sbin/crm corosync get totem.consensus >> $LogFile

  # HDB-HA-SLE-0009
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0009 Pacemaker corosync max_messages" >> $LogFile
  sudo /usr/sbin/crm corosync get totem.max_messages >> $LogFile

  # HDB-HA-SLE-0010
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0010 Pacemaker corosync expected_votes" >> $LogFile
  sudo /usr/sbin/crm corosync get quorum.expected_votes >> $LogFile

  # HDB-HA-SLE-0011
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0011 Pacemaker corosync two_node" >> $LogFile
  sudo /usr/sbin/crm corosync get quorum.two_node >> $LogFile

  # HDB-HA-SLE-0012
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0012 Pacemaker watchdog timeout" >> $LogFile
  expectedresult='Timeout (watchdog) : 60'; result=0; for i in $(echo '$_ClearTextPassword' | sudo -S cat /etc/sysconfig/sbd | grep '^SBD_DEVICE' | cut -d '=' -f 2 | tr -d '\"' | tr ';' ' '); do resultcommand=$(echo '$_ClearTextPassword' | sudo -S sbd -d ${i} dump | grep watchdog); if [[ $resultcommand == $expectedresult ]]; then result=$((result + 1)); else result=$((result - 10)); fi; done; if [ $result -gt 0 ]; then echo 'OK'; else echo 'ERROR'; fi >> $LogFile

  # HDB-HA-SLE-0013
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0013 Pacemaker msgwait timeout" >> $LogFile
  expectedresult='Timeout (msgwait)  : 120'; result=0; for i in $(echo '$_ClearTextPassword' | sudo -S cat /etc/sysconfig/sbd | grep '^SBD_DEVICE' | cut -d '=' -f 2 | tr -d '\"' | tr ';' ' '); do resultcommand=$(echo '$_ClearTextPassword' | sudo -S sbd -d ${i} dump | grep msgwait); if [[ $resultcommand == $expectedresult ]]; then result=$((result + 1)); else result=$((result - 10)); fi; done; if [ $result -gt 0 ]; then echo 'OK'; else echo 'ERROR'; fi >> $LogFile

  # HDB-HA-SLE-0014
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0014 Pacemaker concurrent fencing" >> $LogFile
  sudo /usr/sbin/crm configure show | grep 'concurrent-fencing' >> $LogFile

  # HDB-HA-SLE-0015
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0015 Pacemaker number of fence_azure_arm instances" >> $LogFile
  sudo /usr/sbin/crm configure show | grep 'stonith:fence_azure_arm' >> $LogFile

  # HDB-HA-SLE-0017
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0017 Pacemaker softdog config file" >> $LogFile
  sudo /bin/cat /etc/modules-load.d/softdog.conf >> $LogFile

  # HDB-HA-SLE-0018
  echo "### --------------------------------------------------" >> $LogFile
  echo "### HDB-HA-SLE-0018 Pacemaker softdog module loaded" >> $LogFile
  sudo lsmod | grep softdog | wc -l >> $LogFile
fi

# HDB-OS-SLES-0005
echo "### --------------------------------------------------" >> $LogFile
echo "### HDB-OS-SLES-0005 Mellanox TX timeout - CPU soft lockup" >> $LogFile
uname -a >> $LogFile

# APP-OS-0001
echo "### --------------------------------------------------" >> $LogFile
echo "### APP-OS-0001 IPv4 keepalive time" >> $LogFile
sudo /sbin/sysctl net.ipv4.tcp_keepalive_time >> $LogFile

# APP-OS-0002
echo "### --------------------------------------------------" >> $LogFile
echo "### APP-OS-0002 IPv4 tcp_retries2" >> $LogFile
sudo /sbin/sysctl net.ipv4.tcp_retries2 >> $LogFile

# APP-OS-0003
echo "### --------------------------------------------------" >> $LogFile
echo "### APP-OS-0003 IPv4 keepalive interval" >> $LogFile
sudo /sbin/sysctl net.ipv4.tcp_keepalive_intvl >> $LogFile

# APP-OS-0004
echo "### --------------------------------------------------" >> $LogFile
echo "### APP-OS-0004 IPv4 keepalive probes" >> $LogFile
sudo /sbin/sysctl net.ipv4.tcp_keepalive_probes >> $LogFile

# APP-OS-0005
echo "### --------------------------------------------------" >> $LogFile
echo "### APP-OS-0005 IPv4 tcp_tw_recycle" >> $LogFile
sudo /sbin/sysctl net.ipv4.tcp_tw_recycle >> $LogFile

# APP-OS-0006
echo "### --------------------------------------------------" >> $LogFile
echo "### APP-OS-0006 IPv4 tcp_tw_reuse" >> $LogFile
sudo /sbin/sysctl net.ipv4.tcp_tw_reuse >> $LogFile

# APP-OS-0007
echo "### --------------------------------------------------" >> $LogFile
echo "### APP-OS-0007 IPv4 tcp_retries1" >> $LogFile
sudo /sbin/sysctl net.ipv4.tcp_retries1 >> $LogFile

# HDB-OS-0002
echo "### --------------------------------------------------" >> $LogFile
echo "### HDB-OS-0002 swap space" >> $LogFile
free | grep Swap | awk '{print $2}' >> $LogFile

if [ "$ASCS" = "1" ]; then
  # ASCS-HA-SLE-0001
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0001 Pacemaker Stonith enabled" >> $LogFile
  sudo /usr/sbin/crm configure show | grep 'stonith-enabled=true' >> $LogFile

  # ASCS-HA-SLE-0002
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0002 Pacemaker Stonith timeout" >> $LogFile
  sudo /usr/sbin/crm configure show | grep 'stonith-timeout' >> $LogFile

  # ASCS-HA-SLE-0003
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0003 Pacemaker corosync token" >> $LogFile
  sudo /usr/sbin/crm corosync get totem.token >> $LogFile

  # ASCS-HA-SLE-0004
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0004 Pacemaker totem.token_retransmits_before_loss_const" >> $LogFile
  sudo /usr/sbin/crm corosync get totem.token_retransmits_before_loss_const >> $LogFile

  # ASCS-HA-SLE-0005
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0005 Pacemaker corosync join" >> $LogFile
  sudo /usr/sbin/crm corosync get totem.join >> $LogFile

  # ASCS-HA-SLE-0006
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0006 Pacemaker corosync consensus" >> $LogFile
  sudo /usr/sbin/crm corosync get totem.consensus >> $LogFile

  # ASCS-HA-SLE-0007
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0007 Pacemaker corosync max_messages" >> $LogFile
  sudo /usr/sbin/crm corosync get totem.max_messages >> $LogFile

  # ASCS-HA-SLE-0008
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0008 Pacemaker corosync expected_votes" >> $LogFile
  sudo /usr/sbin/crm corosync get quorum.expected_votes >> $LogFile

  # ASCS-HA-SLE-0009
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0009 Pacemaker corosync two_node" >> $LogFile
  sudo /usr/sbin/crm corosync get quorum.two_node >> $LogFile

  # ASCS-HA-SLE-0010
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0010 Pacemaker watchdog timeout" >> $LogFile
  expectedresult='Timeout (watchdog) : 60'; result=0; for i in $(echo '$_ClearTextPassword' | sudo -S cat /etc/sysconfig/sbd | grep '^SBD_DEVICE' | cut -d '=' -f 2 | tr -d '\"' | tr ';' ' '); do resultcommand=$(echo '$_ClearTextPassword' | sudo -S sbd -d ${i} dump | grep watchdog); if [[ $resultcommand == $expectedresult ]]; then result=$((result + 1)); else result=$((result - 10)); fi; done; if [ $result -gt 0 ]; then echo 'OK'; else echo 'ERROR'; fi >> $LogFile

  # ASCS-HA-SLE-0011
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0011 Pacemaker msgwait timeout" >> $LogFile
   xpectedresult='Timeout (msgwait)  : 120'; result=0; for i in $(echo '$_ClearTextPassword' | sudo -S cat /etc/sysconfig/sbd | grep '^SBD_DEVICE' | cut -d '=' -f 2 | tr -d '\"' | tr ';' ' '); do resultcommand=$(echo '$_ClearTextPassword' | sudo -S sbd -d ${i} dump | grep msgwait); if [[ $resultcommand == $expectedresult ]]; then result=$((result + 1)); else result=$((result - 10)); fi; done; if [ $result -gt 0 ]; then echo 'OK'; else echo 'ERROR'; fi >> $LogFile

  # ASCS-HA-SLE-0012
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0012 Pacemaker concurrent fencing" >> $LogFile
  sudo /usr/sbin/crm configure show | grep 'concurrent-fencing' >> $LogFile

  # ASCS-HA-SLE-0013
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0013 Pacemaker number of fence_azure_arm instances" >> $LogFile
  sudo /usr/sbin/crm configure show | grep 'stonith:fence_azure_arm' >> $LogFile

  # ASCS-HA-SLE-0015
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0015 Pacemaker softdog config file" >> $LogFile
  sudo /bin/cat /etc/modules-load.d/softdog.conf >> $LogFile

  # ASCS-HA-SLE-0018
  echo "### --------------------------------------------------" >> $LogFile
  echo "### ASCS-HA-SLE-0018 Pacemaker softdog module loaded" >> $LogFile
  sudo lsmod | grep softdog | wc -l >> $LogFile
fi
