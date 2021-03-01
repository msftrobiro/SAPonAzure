# Running the automation from the deployer VM

The deployer VM has all the prerequisites for deployment installed including the a clone of the sap-hana repository.

Connect to the deployer vm using ssh.

1. Navigate to the “Azure_SAP_Automated_Deployment” directory
2. Export the required environment variables

```bash
export DEPLOYMENT_REPO_PATH=~/Azure_SAP_Automated_Deployment/sap-hana/
export ARM_SUBSCRIPTION_ID=8d8422a3-a9c1-4fe9-b880-adcf61557c71

cd sap-hana
git checkout beta
```

3. Copy the sample parameter folders with

```bash
cp sap-hana/documentation/SAP_Automation_on_Azure/Process_Documentation/WORKSPACES WORKSPACES/ -r
```

Navigate to the ~/Azure_SAP_Automated_Deployment/WORKSPACES/DEPLOYMENT-ORCHESTRATION folder.

The deployment will need the Service Principal details (application id, secret and tenant ID)

## **Deploying the environment**

For deploying the supporting infrastructure (Deployer, Library and Workload zone) use the install_environment.sh script

${DEPLOYMENT_REPO_PATH}deploy/scripts/install_environment

-d DEPLOYER/DEV-WEEU-DEP00-INFRASTRUCTURE/DEV-WEEU-DEP00-INFRASTRUCTURE.json -l LIBRARY/DEV-WEEU-SAP_LIBRARY/DEV-WEEU-SAP_LIBRARY.json -e LANDSCAPE/DEV-WEEU-SAP01-INFRASTRUCTURE/DEV-WEEU-SAP00-INFRASTRUCTURE.json

The script will deploy the deployment infrastructure and create the Azure keyvault for storing the Service Principal details. When prompted for the environment details enter “PROD” and then enter the Service Principal details. The script will them deploy the rest of the resources required.

## **Deploying the SAP system**

For deploying the SAP system navigate to the folder containing the parameter file and use the installer.sh script.

```bash
${DEPLOYMENT_REPO_PATH}deploy/scripts/installer.sh -p DEV-WEEU-SAP01-ZZZ.json -t sap_system
```
