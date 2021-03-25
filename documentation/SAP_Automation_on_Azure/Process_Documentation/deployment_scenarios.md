# ![SAP Deployment Automation Framework](../assets/images/UnicornSAPBlack64x64.png)**SAP Deployment Automation Framework** #

# Deployment Scenarios #

The SAP Deployment Automation Framework support the following deployment models

## Greenfield deployment ##

In this scenario All Azure artifacts will be created by the automation

### Greenfield deployment using the deployer ###

This scenario contains the following deployments

- Deployer
- Library
- Workload(s)
- System(s)

A sample configuration for this is available here

| Component                | Template |
| :------------------------|  :----------------------------------------------------------------------- |
| Deployer  | [Deployer](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/DEPLOYER/MGMT-WEEU-DEP00-INFRASTRUCTURE/MGMT-WEEU-DEP00-INFRASTRUCTURE.json)
| Library  | [Library](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/LIBRARY/MGMT-WEEU-SAP_LIBRARY/MGMT-WEEU-SAP_LIBRARY.json)
| Workload  | [Workload](./WORKSPACES//DEPLOYMENT-ORCHESTRATION/LANDSCAPE/DEV-WEEU-SAP01-INFRASTRUCTURE/DEV-WEEU-SAP01-INFRASTRUCTURE.json)
| System  | [Library](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/SYSTEM/DEV-WEEU-SAP01-ZZZ/DEV-WEEU-SAP01-ZZZ.json)

### Greenfield deployment without the deployer ###

This scenario contains the following deployments:

- Library
- Workload(s)
- System(s)

A sample configuration for this is available here

| Component                | Template |
| :------------------------|  :----------------------------------------------------------------------- |

| Library  | [Library](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/LIBRARY/MGMT-WEEU-SAP_LIBRARY/MGMT-WEEU-SAP_LIBRARY.json)
| Workload  | [Workload](./WORKSPACES//DEPLOYMENT-ORCHESTRATION/LANDSCAPE/DEV-WEEU-SAP01-INFRASTRUCTURE/DEV-WEEU-SAP01-INFRASTRUCTURE.json)
| System  | [Library](./WORKSPACES/DEPLOYMENT-ORCHESTRATION/SYSTEM/DEV-WEEU-SAP01-ZZZ/DEV-WEEU-SAP01-ZZZ.json)

The scenario requires an existing key vault that contain the SPN credentials for the workload zone SPN.


## Brownfield deployment ##

In this scenario All Azure artifacts will be created by the automation