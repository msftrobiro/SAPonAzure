## Deploy SAP systems in Azure - deployment, OS actions and SAP ABAP & HANA install.

# Still work-in-progress
Self imposed deadline (those work best!) end of Oct

### Aim of this project
- a demonstration that beyond the typical ARM templates and 3rd party tools such as Ansible/Terraform and others, Azure CLI and simple Linux bash scripts can easily be utilized to automatically deploy and install everything from scratch - networks, VMs, storage, OS config and SAP/HANA installation
- Azure ARM templates can be complicated beasts which - in this authors opinion - are overused and hard to troubleshoot, AZ CLI on other hand can quickly become second nature particularly for IaaS deployments
- Learning exercise coupled with need for quick-to-spinup demo SAP system with full high availability desing (sans the cluster setup)
- A starting point for own additions and tests

# What this is project IS NOT
- In any way directly affiliated with Microsoft or endorsed by Microsoft. All opinions and statements contained herein are private and not necessarility the opinion of my employer, Microsoft.
- Not to be used in production. 
- Scripts have hardly any error handling, troubleshooting is on you in case things don't work as expected.
- While resources in this project are deployed in Availablity Zones, that doesn't mean it's the be-all-end-all for SAP systems in Azure. Far from it, very often going without AvZones is the better choice as they can introduce many other issues you'd not consider before.
- Not a showcase of coding skills. I'm not a coder/scripter so a lot is not optimal and likely to be improved. Any non-condescending advise with example much appreciated :)


## What this project does
If configured correctly it would deploy virtual networks - central hub and SAP spoke - with subnets, NSGs, load balancers.
SAP infrastructure for a single highly available system consisting of 2 ASCS VMs, 2 dedicated applications server VMs and 2 HANA VMs
No clustering or active failover mechanism in use, however this can be extended with own actions or scripts, as needed.
Storage design leans on cost-concious setup with Standard_SSDs mostly, yet still using LVM striping on PremSSD for hana data and log.
 --- insert Visio here ---
 - OS info
 - VM listing, sizing
 - software version
 
# Prerequisites for use
- Software download and storage account - Azure Storage Account with your chosen name and blob container, using access keys for authentication.
- SAP software can only be sourced from SAP, you need to provide following files in your storage account blob container. 
    - Linux SAPCAR executable (not SAR archive), named sapcar_linux
    - Linux SWPM SAR file, latest version, named SWPM.SAR
    - Linux SAP ABAP Kernel SAR file, latest version for Netweaver 7.50 (e.g. SAPEXE_753), named SAPEXE.SAR
    - Linux SAP ABAP Kernel disp+work SAR file, matching the above kernel, named DW.SAR
    - Linux SAP ABAP HANA Kernel SAR file, same version as above kernel, named SAPEXEDB.SAR
    - Linux SAP Host Agent in latest version as SAR file, named SAPHOSTAGENT.SAR
    - Linux HANA DB Server patch, for latest version HANA2, named IMDB_SERVER.SAR
    - Linux HANA Client patch, latest version for HANA2, named IMDB_CLIENT.SAR
    - ... more, export cds ,igs etc


- Availability zones must be enabled for deployment on your Azure subscription, in chosen region. Alternatively edit script 2_create_SAP_infra to remove zonal deployment for VMs.
- Deployment requires about 44 vCores of Ds_v3 VMs. Ensure you have sufficient vcore allocation available.
- Parameters.txt file used for deployment contains details such as storage account housing all files (in your or somebody's else subscription), names and SIDs, master password to use

# How to deploy
Pull all files off this project to separate folder - e.g. git pull https://github.com/msftrobiro/SAPonAzure/edit/master/temp_sap_systems

Alternatively, just download the 1_create_jumpbox.sh with parameters.txt to your Linux system (Azure cloudshell or Windows Linux Host both work).

Edit parameters.txt and provide the required values, observe the upper/lowercase information (which means ALL characters should be upper/lowercase).

Execute 1_create_jumpbox.txt and typically in 10 minutes you have your Linux jumphost ready to go and continue.

On jumpbox - follow output of the first script - execute the predownloaded 2_... script and your parameters.txt is copied from your previous shell, keeping your values.

### Steps in code
- download all files (linux environment)
- vim parameters.txt
- ./1_create_jumpbox.sh
- 'ssh <username>@<jumpbox>' as displayed by executed previous script
- ./2_create_SAP_infra.sh
- ./3_install_DB_and_App.sh
- '<further scripts, coming down the line/own>'

### Naming convention
Basic naming convention utilized for resources, resource type (VM, VNET, LB, VPN etc) as first character name and location shortname (EUN for EuropeNorth, EUW for EuropeWest etc) are typically used, followed by resource name.

### Changelog
v0.2, Oct 28 2019
- added new parameters to control if db02/app02/ascs02 should be installed at all. If all set to false, only 3 VMs for normal 3tier setup will be deployed
- using PPGs for SAP systems, one PPG per zone
- changed NSGs to subnets and not VM NICs directly

v0.3, Oct 29 2019 (coming!)
- added ERS installation
- added load balancers for DB and ASCS, if setup to use distributed architecture
- cleaned up readme.md (this file)

### Missing features, aka endless ToDo list
- add ERS on ascs02 - 
- LB and possibly FQDN for external access
- Backup integration (optional script)
- ASR setup, as option (low prio, too many variables and rather complex)
- clean-up this page and put more options in scripts, e.g ultra-disks or full prod-sizing with M-series and write accel
- some basic error checking - did you provide values correctly, do ssh keys exist, error code checking
- make sapinst less spammy, redirect
- SSO SAML2 for Web-SAPGui all scripted, incl sap rfc triggered actions in script 
- stop/start script (VM+SAP), interactively
- simple backup script for db and logs with version control
- use azure private dns instead of ugly host file
- ... more things I forget right now


### closing note
Unattended sapinst is terrible, fact.