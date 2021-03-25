
# Process documentation #


The SAP Deployment Automation Framework provides both Terraform templates and Ansible playbooks which can be used to build and configure the environments to run SAP on Azure.
It allows to create an Azure landing zone for the SAP environment (SBX, DEV, QA, PROD), the SAP systems (virtual machine, storage) intended for running HANA, AnyDB and the Premium storage solutions like Premium disks and the automated SAP installation by using Ansible.

The automation framework allows greenfield and brownfield approach. The Terraform scripts used for infrastructure deployment are documented [software documentation](https://github.com/Azure/sap-hana/tree/documentation-updates/documentation/SAP_Automation_on_Azure/Software_Documentation) for information purposes, they should not be changed in order to avoid unwanted deployment results.
This document describes the overall process flow and the design activities needed to prepare and deploy an SAP estate to Azure.

## Architectural overview ##

[SAP Estate](./assets/SAP_estate.jpg)

### Process overview ###
The process consists out of different steps
- deployment of management infrastructure 
- preparing the details for the deployment
- deployment of SAP environment and systems

#### Deployment of the management infrastructure ####

A Terraform (deployment) environment needs to be setup, this is a one-time step achieved by using [scripts](https://github.com/Azure/sap-hana/blob/documentation-updates/documentation/SAP_Automation_on_Azure/Process_Documentation/Deployment_scripts.md)
Here is the overview on how the [repository](https://github.com/Azure/sap-hana/blob/documentation-updates/documentation/SAP_Automation_on_Azure/Process_Documentation/Deployment_folder_structure.md) will look like after running the initial scripts.

#### Preparing the details for the deployment ####

The following [information](https://github.com/Azure/sap-hana/blob/documentation-updates/documentation/SAP_Automation_on_Azure/Process_Documentation/customer_requirements.md) should be available before starting the deployment. It might be necessary to change naming conventions or disk sizings.

#### Changing the naming convention ####

The automation uses a default naming convention which is defined in the Standard naming convention document [standards-naming.md](.//Software_Documentation/standards-naming.md)
[naming conventions for the deployment](https://github.com/Azure/sap-hana/blob/documentation-updates/documentation/SAP_Automation_on_Azure/Process_Documentation/Changing_the_naming_convention.md) should be defined upfront and can be customized according the needs.

#### Changing disk sizing ####

 [Using_custom_disk_sizing.md](./Using_custom_disk_sizing.md)


#### Deployment of SAP environment and systems ####

Parameterization for the specific SAP environment/systems is achieved by customization of JSON scripts [WORKSPACE](https://github.com/Azure/sap-hana/tree/documentation-updates/documentation/SAP_Automation_on_Azure/Process_Documentation/WORKSPACES).


