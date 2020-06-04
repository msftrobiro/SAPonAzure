## What this is:
- A very short example Azure CLI script to deploy a sample, very limited 3 tier SAP system. Why CLI? Because I find it the easiest semi-automated way to deploy and lower barrier of entry than Powershell, ARM or 3rd party tools like Terraform. All those tools are more powerful but can be daunting to learn for a beginner.
- By itself the script would deploy:
    - new resource group
    - new vnet with 2 subnets (appl, db)
    - 2 NSGs applied to each subnet respectively
    - proximity placement group for this SAP system
    - 3 VMs with just private IPs, 1 ASCS, 1 App Server, 1 DB
    - very basic storage with just one single data disk for the DB server

## What this is **NOT**:
- In any way directly affiliated with Microsoft or endorsed by Microsoft. All opinions and statements contained herein are private and not necessarility the opinion of my employer, Microsoft.
- Script does not contain other crucial elements
    - NSG rules
    - tags
    - static IP handling
    - VM boot diagnostics
    - Monitoring/logging
    - DNS for vnets
    - many more I forget right now
- To be used for production deployments, read the disclaimer.
- No software installation automation example, it is purely IaaS components


# Disclaimer

**THE SCRIPTS ARE PROVIDED AS IS WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.**

## Contributing

This project has adopted the Microsoft Open Source Code of Conduct. For more information see the Code of Conduct FAQ or contact opencode@microsoft.com with any additional questions or comments.