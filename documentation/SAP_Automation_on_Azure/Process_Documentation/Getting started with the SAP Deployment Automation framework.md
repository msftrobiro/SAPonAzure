# Getting started with the SAP Deployment Automation framework.

## Choosing the orchestration environment

The SAP Deployment Automation Framework provides both Terraform templates and Ansible playbooks which can be used to build and configure the environments to run SAP on Azure. 

The SAP Deployment Automation framework can be executed from different run time environments. Currently the supported environments are:

- Azure Cloud Shell
- Azure hosted Virtual Machine
- Local PC
###
### Sample files

The repository contains a folder that has a set of sample parameter files that can be used to deploy the supporting components and the SAP System.

The folder is located in the documentation/SAP\_Automation\_on\_Azure/Process\_Documentation/WORKSPACES folder MAKE LINK

The folder structure is documented here: [LINK]

### Running the automation from Azure cloud shell
The Azure cloud shell has all the prerequisites for deployment, as it as both the Azure CLI and Terraform installed.
#### *Preparing the cloud shell* 
To be able to run the deployments from the cloud shell we need to clone the sap-hana repository to a directory in cloud shell. 

Open the cloud shell and use bash.

1. Navigate to the root directory of the cloud shell
1. Create a directory “Azure\_SAP\_Automated\_Deployment”
1. Clone the sap-hana repository by running the 

git clone <https://github.com/Azure/sap-hana.git> command

1. Export the required environment variables
   1. export DEPLOYMENT\_REPO\_PATH=~/Azure\_SAP\_Automated\_Deployment/sap-hana/
   1. export ARM\_SUBSCRIPTION\_ID=8d8422a3-a9c1-4fe9-b880-adcf61557c71
1. Copy the sample parameter folders with 

cp sap-hana/documentation/SAP\_Automation\_on\_Azure/Process\_Documentation/WORKSPACES WORKSPACES/ -r

The deployment will need the Service Principal details (application id, secret and tenant ID)
#### *Deploying the environment*

For deploying the supporting infrastructure (Deployer, Library and Workload zone) use the install\_environment.sh script 

${DEPLOYMENT\_REPO\_PATH}deploy/scripts/install\_environment 

-d DEPLOYER/PROD-WEEU-DEP00-INFRASTRUCTURE/PROD-WEEU-DEP00-INFRASTRUCTURE.json -l LIBRARY/PROD-WEEU-SAP\_LIBRARY/PROD-WEEU-SAP\_LIBRARY.json -e LANDSCAPE/PROD-WEEU-SAP00-INFRASTRUCTURE/PROD-WEEU-SAP00-INFRASTRUCTURE.json

The script will deploy the deployment infrastructure and create the Azure keyvault for storing the Service Principal details. When prompted for the environment details enter “PROD” and then enter the Service Principal details. The script will them deploy the rest of the resources required.
#### *Deploying the SAP system*

For deploying the SAP system navigate to the folder containing the parameter file and use the installer.sh script 

${DEPLOYMENT\_REPO\_PATH}deploy/scripts/installer.sh -p PROD-WEEU-SAP00-ZZZ.json -t sap\_system

### Running the automation from the deployer VM
The deployer VM has all the prerequisites for deployment installed including the a clone of the sap-hana repository.
#### *Connect to the deployer vm using ssh* 

1. Navigate to the “Azure\_SAP\_Automated\_Deployment” directory
1. Export the required environment variables
   1. export DEPLOYMENT\_REPO\_PATH=~/Azure\_SAP\_Automated\_Deployment/sap-hana/
   1. export ARM\_SUBSCRIPTION\_ID=8d8422a3-a9c1-4fe9-b880-adcf61557c71
1. Copy the sample parameter folders with 

cp sap-hana/documentation/SAP\_Automation\_on\_Azure/Process\_Documentation/WORKSPACES WORKSPACES/ -r

The deployment will need the Service Principal details (application id, secret and tenant ID)
#### *Deploying the environment*

For deploying the supporting infrastructure (Deployer, Library and Workload zone) use the install\_environment.sh script 

${DEPLOYMENT\_REPO\_PATH}deploy/scripts/install\_environment 

-d DEPLOYER/PROD-WEEU-DEP00-INFRASTRUCTURE/PROD-WEEU-DEP00-INFRASTRUCTURE.json -l LIBRARY/PROD-WEEU-SAP\_LIBRARY/PROD-WEEU-SAP\_LIBRARY.json -e LANDSCAPE/PROD-WEEU-SAP00-INFRASTRUCTURE/PROD-WEEU-SAP00-INFRASTRUCTURE.json

The script will deploy the deployment infrastructure and create the Azure keyvault for storing the Service Principal details. When prompted for the environment details enter “PROD” and then enter the Service Principal details. The script will them deploy the rest of the resources required.
#### *Deploying the SAP system*

For deploying the SAP system navigate to the folder containing the parameter file and use the installer.sh script 

${DEPLOYMENT\_REPO\_PATH}deploy/scripts/installer.sh -p PROD-WEEU-SAP00-ZZZ.json -t sap\_system
###
### Running the automation from a Windows PC

In order to be able to run the automation from a local Winds PC the following components need to be installed.

1. Terraform, Terraform can be downloaded from [Download Terraform - Terraform by HashiCorp](https://www.terraform.io/downloads.html), once downloaded and extracted ensure that the Terraform.exe executable is in a directory that is included in the SYSTEM PATH variable.
1. Git, Git can be installed from [Git (git-scm.com)](https://git-scm.com/)
1. Azure CLI, Azure CLI can be installed from <https://aka.ms/installazurecliwindows> 
1. Azure PowerShell, Azure PowerShell can be installed from [Install Azure PowerShell with PowerShellGet | Microsoft Docs](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-5.5.0)
1. The latest Azure PowerShell modules, <https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-5.5.0#update-the-azure-powershell-module> 

1. Create a root directory “Azure\_SAP\_Automated\_Deployment”
1. Navigate to the “Azure\_SAP\_Automated\_Deployment” directory
1. Clone the sap-hana repository by running the 

git clone <https://github.com/Azure/sap-hana.git> command

1. Copy the sample parameter folder from

sap-hana\documentation\SAP\_Automation\_on\_Azure\Process\_Documentation\WORKSPACES to the “Azure\_SAP\_Automated\_Deployment” folder

The deployment will need the Service Principal details (application id, secret and tenant ID)
#### *Deploying the environment*

Import the Powershell module by running the 

Import-Module  C:\Azure\_SAP\_Automated\_Deployment\sap-hana\deploy\scripts\pwsh\SAPDeploymentUtilities\Output\SAPDeploymentUtilities\SAPDeploymentUtilities.psd1

For deploying the supporting infrastructure (Deployer, Library and Workload zone) use the New-Environment cmdlet

New-Environment -DeployerParameterfile .\DEPLOYER\PROD-WEEU-DEP00-INFRASTRUCTURE\PROD-WEEU-DEP00-INFRASTRUCTURE.json  -LibraryParameterfile .\LIBRARY\PROD-WEEU-SAP\_LIBRARY\PROD-WEEU-SAP\_LIBRARY.json -EnvironmentParameterfile .\LANDSCAPE\PROD-WEEU-SAP00-INFRASTRUCTURE\PROD-WEEU-SAP00-INFRASTRUCTURE.json

The script will deploy the deployment infrastructure and create the Azure keyvault for storing the Service Principal details. When prompted for the environment details enter “PROD” and then enter the Service Principal details. The script will them deploy the rest of the resources required.
#### *Deploying the SAP system*

For deploying the SAP system navigate to the folder containing the parameter file and use the New-System cmdlet

`	`New-System -Parameterfile .\PROD-WEEU-SAP00-ZZZ.json -Type sap\_system



















