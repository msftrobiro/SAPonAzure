# Getting started with the SAP Deployment Automation framework #

The SAP Deployment Automation Framework provides both Terraform templates and Ansible playbooks which can be used to build and configure the environments to run SAP on Azure.

## Table of Contents <!-- omit in toc --> ##

- [Planning](##Planning-environment)
  - [DevOps planning](###DevOps-planning)
  - [Region planning](###Regional-planning)
  - [Workload planning](###Workload-zone-planning)
- [Deployment Environment](###Deployment-environment)
- [SAP Library](###SAP-Library)

## Planning ##

Before deploying the SAP Systems there are a few design decisions that need to be made. This section covers the high level steps for the planning process

### **DevOps planning** ###

The Terraform automation templates are hosted in the public sap-hana github repository. In most cases customers should treat this folder as read only.

The deployment automation leverages json parameter files to configure the Azure environment. It is highly recommended that these parameter files would be stored in the customers source control environment. For more details on how to optimally structure the folder hierarchy for the deployment parameter files see [Folder hierarchy](./Deployment_folder_structure.md). Having the parameter files in a predefined folder structure will simplify automated deployment operations.

The default deployment model of the SAP Deployment Automation Framework will deploy an Azure Virtual Machine that can be used to execute the deployment activities, future versions of the framework will provide means to use other execution environment as well (Azure DevOps)

### **Regional planning** ###

The SAP Deployment Automation supports deployments in multiple Azure Regions. Each region will host:

- Deployment infrastructure
- SAP Library for state and SAP installation media
- 1-n Workload zones
- 1-n SAP systems deployed in the Workload Zones.

#### Design questions - regions ####

- Which Azure regions are in scope?

#### **Deployment environment** ####

The deployment environment provides the following services

1. Deployment Virtual Machine, this virtual machine can be used to perform both the Terraform deployments as well as the Ansible configurations.
2. Azure Keyvault, this keyvault will containg the Service Principal details and will be used by the Terraform deployments
3. Azure Firewall, this optional component is used to provide outbound Internet connectivity.

#### Configuring the deployment environment ####

The deployment configuration file defines the region and the environment name and the Virtual Network information for the Deployment Virtual Machine.

   ```json
   {
      "infrastructure": {
         "region": "westeurope",
         "environment": "DEV",
         "vnets": {
               "management": {
                  "address_space": "10.10.20.0/25",
                  "subnet_mgmt": {
                     "prefix": "10.10.20.64/28"
                  }
               }
         }
      }
   }
   ```

A sample deployment environment configuration is specified in [Deployment Environment](WORKSPACES/DEPLOYMENT-ORCHESTRATION/DEPLOYER/DEV-WEEU-DEP00-INFRASTRUCTURE/DEV-WEEU-DEP00-INFRASTRUCTURE.json)

For more details on the deployer see [Deployer](../Software_Documentation\product_documentation-deployer.md)

For more details on the configuration of the deployer see [Deployment Configuration](../Software_Documentation/configuration-deployer.md)

#### **SAP Library** ####

The SAP Library provides the following services:

- Storage for the Terraform state files
- Storage for the SAP Installation media

#### Configuring the SAP Library ####

The SAP Library configuration file defines the region and the environment name .

```json
   {
      "infrastructure": {
         "region": "westeurope",
         "environment": "DEV",
         "resource_group": {
            "name" : "WEEU-SAP_LIBRARY"
         }
      },
      "deployer": {
         "environment": "DEV",
         "region": "westeurope",
         "vnet": "MGMT00"
      }
   }
```

A sample deployment for the SAP library configuration is specified in [Library Environment](WORKSPACES/DEPLOYMENT-ORCHESTRATION/LIBRARY/DEV-WEEU-SAP_LIBRARY/DEV-WEEU-SAP_LIBRARY.json)

For more details on the SAP Library see [SAP Library](../Software_Documentation\product_documentation-sap_library.md)
For more details on the configuration of the SAP Library see [SAP Library Configuration](../Software_Documentation/configuration-sap_library.md)

### **Workload zone planning** ###

An SAP Application has typically multiple development tiers, for instance development, quality assurance and production. The SAP Deployment Automation refers to these as workload zones.

A workload zone combines the workload Virtual Network and the set of credentials to be used in the systems in that workload as well as the Service Principal that is used for deploying systems. The Workload Zones are regional because they depend on the Azure Virtual Network. The naming convention of the automation supports having workload zones in multiple Azure regions each with their own virtual network.

Some common patterns for workload zones are:

#### Production and Non-Production ####

In this model the SAP environments are partitioned into two zones, production and non production.

#### Development, Quality Assurance, Production ####

In this model the SAP environments are partitioned into three zones, development, quality Assurance, production

#### Design questions - workload zone ####

How many workload zones are required?
Which regions are the workloads deployed to?
Is the deployment a Greenfield deployment (no Azure Infrastructure for the Workload exists) or a Brownfield deployment (some or all of the artifacts supporting the workload zone already exists)?

#### **Workload Zone** ####

The Workload Zone provides the following services:

- Azure Virtual Network
- Azure Keyvault for system credentials

#### Configuring the Workload Zone ####

The Workload Zone configuration file defines the region and the environment name as well as the Virtual Network information (existing or new). The configuration also allows for specifying the default credentials (username and password or ssh keys) that will be used by the SAP Systems deployments-

```json
   {
      "authentication": {
         "username": "azureadm"
      },
      "infrastructure": {
         "environment": "DEV",
         "region": "westeurope",
         "vnets": {
               "sap": {
                  "name" :"SAP01",
                  "address_space": "10.110.0.0/24"
               }
         }
      }
   }
```

A sample workload zone configuration is specified in [Workload Zone Environment](WORKSPACES/DEPLOYMENT-ORCHESTRATION/LANDSCAPE/DEV-WEEU-SAP00-INFRASTRUCTURE/DEV-WEEU-SAP01-INFRASTRUCTURE.json)

The deployment will create a Virtual network and a storage account for boot diagnostics and a storage account which can be used as the witness disk for Windows High Availability Architectures and two key vaults. The deployment will populate the keyvault with the default credentials for the Virtual Machines.

For more details on the Workload Zone see [Workload Zone](../Software_Documentation/product_documentation-sap-workloadzone.md)
For more details on the configuration of the SAP Library see [Workload Zone Configuration](../Software_Documentation/configuration-sap_workloadzone.md)

### **SAP System**

The SAP System configuration is specified in [SAP System](WORKSPACES/DEPLOYMENT-ORCHESTRATION/SYSTEM/DEV-WEEU-SAP00-ZZZ/DEV-WEEU-SAP01-ZZZ.json)

The deployment will create a SAP system that has an Hana database server, 2 application servers, 1 central services server and a web dispatcher and two key vaults (which can be ignored for now).

The deployment will require using a Service principal.

1. Create SPN

From a privilaged account, create an SPN.

```bash
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" --name="Deployment Account-DEV"
```

2. Record the credential outputs.
   The pertinant fields are:
   - appId
   - password
   - tenant

```json
    {
      "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "displayName": "Deployment Account-NP",
      "name": "http://Deployment-Account-NP",
      "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx""
    }
 ```

3. Add Role Assignment to SPN.

```bash
az role assignment create --assignee <appId> --role "User Access Administrator"
```
## Deployment flow

The deployment flow has three steps: Preparing the region, preparing the environment(s) and deploying the systems.


### Prepare the region

This step deploys the required artifacts to support the SAP Automation framework in a specifed Azure region.
This includes creating the deployment environment and the shared storage for Terraform statefiles as well as the SAP installation media.

### Preparing the environment

This step deploys the Workload Zone specific aritfacts: the Virtual Network and the Azure Key Vaults used for credentials management.

### Deploying the system

This step deploys the actual infrastructure for the SAP System (SID)

## Sample files

The repository contains a folder [WORKSPACES](WORKSPACES) that has a set of sample parameter files that can be used to deploy the supporting components and the SAP System. The folder structure is documented here: [Deployment folder structure](Deployment_folder_structure.md)

The name of the environment is **DEV** and it is deployed to West Europe. The SID of the application is ZZZ.

The sample deployment will create a deployment environment, the shared library for state management, the workload virtual network and a SAP system.

## Choosing the orchestration environment

The templates and scripts need to be executed from an execution environment, currently the supported environments are:

- Azure Cloud Shell
- Azure hosted Virtual Machine
- Local PC

The links below explain how to deploy using the different deployment environments.

[Deploying from cloud shell](./Getting_started_with_the_SAP_Deployment_Automation_cloudshell.md)

[Deploying from the Deployer](./Getting_started_with_the_SAP_Deployment_Automation_bash.md)

[Deploying using PowerShell](./Getting_started_with_the_SAP_Deployment_Automation_pwsh.md)
