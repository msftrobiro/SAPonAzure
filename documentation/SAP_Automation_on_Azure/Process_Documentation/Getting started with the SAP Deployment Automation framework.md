# Getting started with the SAP Deployment Automation framework

## Preparation activities



## Sample files

The repository contains a folder [WORKSPACES](WORKSPACES) that has a set of sample parameter files that can be used to deploy the supporting components and the SAP System. The folder structure is documented here: [Deployment folder structure](Deployment_folder_structure.md)

The name of the environment is **PROD** and it is deployed to West Europe. The SID of the application is ZZZ.

The sample deployment will create a deployment environment, the shared library for state management, the workload virtual network and a SAP system.

### **Deployment environment**

The deployment environment configuration is specified in [Deployment Environment](WORKSPACES/DEPLOYMENT-ORCHESTRATION/DEPLOYER/PROD-WEEU-DEP00-INFRASTRUCTURE/PROD-WEEU-DEP00-INFRASTRUCTURE.json)

The deployment will contain an Ubuntu Virtual machine, and the key vault to store the SPN secrets.

### **Shared Library**

The shared library configuration is specified in [Library Environment](WORKSPACES/DEPLOYMENT-ORCHESTRATION/LIBRARY/PROD-WEEU-SAP_LIBRARY/PROD-WEEU-SAP_LIBRARY.json)

The deployment will create two storage accounts and two key vaults (which can be ignored for now)

### **Workload Zone**

The workload zone configuration is specified in [Workload Zone Environment](WORKSPACES/DEPLOYMENT-ORCHESTRATION/LANDSCAPE/PROD-WEEU-SAP00-INFRASTRUCTURE/PROD-WEEU-SAP00-INFRASTRUCTURE.json)

The deployment will create a Virtual network and a storage accounts for boot diagnostics and two key vaults (which can be ignored for now). The deployment will also populate the keyvault in the deployment environment with the default credentials for the Virtual Machines

### **SAP System**

The SAP System configuration is specified in [SAP System](WORKSPACES/DEPLOYMENT-ORCHESTRATION/SYSTEM/PROD-WEEU-SAP00-ZZZ/PROD-WEEU-SAP00-ZZZ.json)

The deployment will create a SAP system that has an Hana database server, 2 application servers, 1 central services server and a web dispatcher and two key vaults (which can be ignored for now).

The deployment will require using a Service principal.

1. Create SPN

From a privilaged account, create an SPN.

```bash
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" --name="Deployment Account-NP"
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

## Choosing the orchestration environment

The SAP Deployment Automation Framework provides both Terraform templates and Ansible playbooks which can be used to build and configure the environments to run SAP on Azure.

The templates and scripts need to be executed from an execution environment, currently the supported environments are:

- Azure Cloud Shell
- Azure hosted Virtual Machine
- Local PC

The links below explain how to deploy using the different deployment environments.

[Deploying from cloud shell](./Getting_started_with_the_SAP_Deployment_Automation_cloudshell.md)
[Deploying from the Deployer](./Getting_started_with_the_SAP_Deployment_Automation_bash.md)
[Deploying using PowerShell](./Getting_started_with_the_SAP_Deployment_Automation_pwsh.md)
