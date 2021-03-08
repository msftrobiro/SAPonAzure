# Getting started with the SAP Deployment Automation framework

The SAP Deployment Automation Framework provides both Terraform templates and Ansible playbooks which can be used to build and configure the environments to run SAP on Azure.

### Table of Contents <!-- omit in toc --> ###

- [Planning](##Planning-environment)
- [Deployment Environment](###Deployment-environment)
- [SAP Library](###SAP Library)

## Planning

### **Deployment environment**

The deployment environment provides the following services

1. Deployment Virtual Machine, this virtual machine can be used to perform both the Terraform deployments as well as the Ansible configurations.
2. Azure Keyvault, this keyvault will containg the Service Principal details and will be used by the Terraform deployments
3. Azure Firewall, this optional component is used to provide outbound Internet connectivity.

#### Configuring the deployment environment

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

### **SAP Library**

The SAP Library provides the following services:

- Storage for the Terraform state files
- Storage for the SAP Installation media

The sample deployment for the SAP library configuration is specified in [Library Environment](WORKSPACES/DEPLOYMENT-ORCHESTRATION/LIBRARY/DEV-WEEU-SAP_LIBRARY/DEV-WEEU-SAP_LIBRARY.json)

For more details on the SAP Library see [SAP Library](../Software_Documentation\product_documentation-sap_library.md)

For more details on the configuration of the SAP Library see [SAP Library Configuration](../Software_Documentation/configuration-sap_library.md)


### **Workload Zone**

The workload zone configuration is specified in [Workload Zone Environment](WORKSPACES/DEPLOYMENT-ORCHESTRATION/LANDSCAPE/DEV-WEEU-SAP00-INFRASTRUCTURE/DEV-WEEU-SAP01-INFRASTRUCTURE.json)

The deployment will create a Virtual network and a storage accounts for boot diagnostics and two key vaults (which can be ignored for now). The deployment will also populate the keyvault in the deployment environment with the default credentials for the Virtual Machines

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
