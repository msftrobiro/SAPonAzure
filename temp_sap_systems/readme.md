## This project can be used to deploy SAP systems in Azure, from scratch including deployment, OS actions and SAP ABAP & HANA install.

### Aim of this was to
- a demonstration that beyond the typical ARM templates and 3rd party tools such as Ansible/Terraform and others, Azure CLI and simple Linux bash scripts can easily be utilized to automatically deploy and install everything from scratch - networks, VMs, storage, OS config and SAP/HANA installation
- ARM templates are complicated beasts which - in this authors opinion - are overused and hard to troubleshoot, AZ CLI on other hand can quickly become second nature for a Linux person
- learning exercise coupled with need for quick-to-spinup demo SAP systems with full high availability desing (sans the cluster setup)

# What this is project IS NOT
- In any way directly affiliated with Microsoft or endorsed by Microsoft. All opinions and statements contained herein are private and not necessarility the opinion of my employer, Microsoft.
- Not to be used in production. 

## What this project does
If configured correctly it would deploy virtual networks - central hub and SAP spoke - with subnets, NSGs, load balancers.
SAP infrastructure for a single highly available system consisting of 2 ASCS VMs, 2 dedicated applications server VMs and 2 HANA VMs
No clustering or active failover mechanism in use, however this can be extended with own actions or scripts, as needed.
 --- insert Visio here ---
 - OS info
 - VM listing, sizing
 - software version
 
# Prerequisites for use
- Software download and storage account
- availability zones active
- vcore limit check
- parameters

# How to deploy

### Naming convention
Basic naming convention utilized for resources, resource type (VM, VNET, LB, VPN etc) as first character name and location shortname (EUN for EuropeNorth, EUW for EuropeWest etc) are typically used, followed by resource name.


### Missing features, aka endless ToDo list
- LB and FQDN for external access
- Backup integration (optional script)
- ASR somewhere, as option
- ... more things I forget right now
