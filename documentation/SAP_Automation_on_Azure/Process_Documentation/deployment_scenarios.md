# ![SAP Deployment Automation Framework](../assets/images/UnicornSAPBlack64x64.png)**SAP Deployment Automation Framework** #

# Deployment Scenarios #

The SAP Deployment Automation Framework support the following deployment models:

# Greenfield deployment #

In this scenario All Azure artifacts will be created by the automation framework.

## **Greenfield deployment using the deployer** ##

This scenario contains the following deployments

- Deployer
- Library
- Workload(s)
- System(s)

A sample configuration for this is available here:

| Component                | Template |
| :------------------------| :----------------------------------------------------------------------- |
| Deployer                 | [Deployer](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/DEPLOYER/MGMT-WEEU-DEP00-INFRASTRUCTURE/MGMT-WEEU-DEP00-INFRASTRUCTURE.json)
| Library                  | [Library](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/LIBRARY/MGMT-WEEU-SAP_LIBRARY/MGMT-WEEU-SAP_LIBRARY.json)
| Workload                 | [Workload](./WORKSPACES//DEPLOYMENT-ORCHESTRATION/LANDSCAPE/DEV-WEEU-SAP01-INFRASTRUCTURE/DEV-WEEU-SAP01-INFRASTRUCTURE.json)
| System                   | [System](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/SYSTEM/DEV-WEEU-SAP01-X00/DEV-WEEU-SAP01-X00.json)

### **Greenfield deployment without the deployer** ###

This scenario contains the following deployments:

- Library
- Workload(s)
- System(s)

A sample configuration for this is available here

| Component                | Template |
| :------------------------| :----------------------------------------------------------------------- |

| Library                  | [Library](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/LIBRARY/MGMT-NOEU-SAP_LIBRARY/MGMT-NOEU-SAP_LIBRARY.json)
| Workload                 | [Workload](./WORKSPACES//DEPLOYMENT-ORCHESTRATION/LANDSCAPE/DEV-NOEU-SAP02-INFRASTRUCTURE/DEV-NOEU-SAP02-INFRASTRUCTURE.json)
| System                   | [Library](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/SYSTEM/DEV-NOEU-SAP02-X02/DEV-NOEU-SAP02-X02.json)

The scenario requires an existing key vault that contains the SPN credentials for the SPN that will be used to deploy the workload zone. This can be defined in the parameter file with the kv_spn_id parameter.

```json
"key_vault" : {
    "kv_spn_id"         : "<ARMresourceID>"
} 

By providing false in the "use" attribute in the deployer section, the automation framwork will not use any information from the deployer state file.

```json
"deployer" : {
    "use": false
} 
```

# Brownfield deployment #

In this scenario the deployment will be performed using existing virtual networks, subnets and network security groups.

## **Brownfield deployment using the deployer** ##

This scenario contains the following deployments

- Deployer
- Library
- Workload(s)
- System(s)

A sample configuration for this is available here

| Component                | Template |
| :------------------------|  :----------------------------------------------------------------------- |
| Deployer                 | [Deployer](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/DEPLOYER/MGMT-EUS2-DEP01-INFRASTRUCTURE/MGMT-EUS2-DEP01-INFRASTRUCTURE.json) |  
| Library                  | [Library](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/LIBRARY/MGMT-EUS2-SAP_LIBRARY/MGMT-EUS2-SAP_LIBRARY.json) |  
| Workload                 | [Workload](./WORKSPACES//DEPLOYMENT-ORCHESTRATION/LANDSCAPE/QA-EUS2-SAP03-INFRASTRUCTURE/QA-EUS2-SAP03-INFRASTRUCTURE.json) |  
| System                   | [System](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/SYSTEM/QA-EUS2-SAP03-X01/QA-EUS2-SAP03-X01.json) |  

## **Brownfield deployment without the deployer** ##

This scenario contains the following deployments:

- Library
- Workload(s)
- System(s)

A sample configuration for this is available here

| Component                | Template |
| :------------------------|  :----------------------------------------------------------------------- |
| Library                  | [Library](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/LIBRARY/MGMT-WUS2-SAP_LIBRARY/MGMT-WUS2-SAP_LIBRARY.json)
| Workload                 | [Workload](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/LANDSCAPE/QA-WUS2-SAP04-INFRASTRUCTURE/QA-WUS2-SAP04-INFRASTRUCTURE.json)
| System                   | [Library](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/SYSTEM/QA-WUS2-SAP04-X03/QA-WUS2-SAP04-X03.json)

The scenario requires an existing key vault that contains the SPN credentials for the SPN that will be used to deploy the workload zone. This can be defined in the parameter file with the kv_spn_id parameter.

```json
"key_vault" : {
    "kv_spn_id"         : "<ARMresourceID>"
} 

By providing false in the "use" attribute in the deployer section, the automation framwork will not use any information from the deployer state file.

```json
"deployer" : {
    "use": false
} 
```

