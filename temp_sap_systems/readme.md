This project can be used to deploy SAP systems in Azure
Aim of this was to
- a demonstration that beyond the typical ARM templates and 3rd party tools such as Ansible/Terraform and others, Azure CLI and simple Linux bash scripts can easily be utilized to automatically deploy and install everything from scratch - networks, VMs, storage, OS config and SAP/HANA installation
- ARM templates are complicated beasts which - in this authors opinion - are overused and hard to troubleshoot, AZ CLI on other hand can quickly become second nature for a Linux person
- learning exercise coupled with need for quick-to-spinup demo SAP systems with full high availability desing (sans the cluster setup)

If configured correctly it would deploy virtual networks - central hub and SAP spoke - with subnets, NSGs, load balancers.
SAP infrastructure for a single highly available system consisting of 2 ASCS VMs, 2 dedicated applications server VMs and 2 HANA VMs
No clustering or active failover mechanism in use, however this can be extended with own actions or scripts, as needed.

