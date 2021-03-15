# Running the automation from Linux


## **Pre-Requisites**

1. **Terraform** - Terraform can be downloaded from [Download Terraform - Terraform by HashiCorp](https://www.terraform.io/downloads.html).
2. **Azure CLI** - Azure CLI can be installed from <https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=script>

## **Deployment** ##

1. Navigate to the home root directory
2. Create a directory "Azure_SAP_Automated_Deployment"
3. Navigate to that directory and clone the sap-hana repository by running:

```bash
git clone <https://github.com/Azure/sap-hana.git> 

cd sap-hana

git checkout beta
```
**Note** If using the deployer the repository is already cloned,

4. Export the required environment variables

    ```bash
    export DEPLOYMENT_REPO_PATH=~/Azure_SAP_Automated_Deployment/sap-hana/
    export ARM_SUBSCRIPTION_ID=8d8422a3-a9c1-4fe9-b880-adcf61557c71

5. Copy the sample parameter folders with

    ```bash
    cd ~/Azure_SAP_Automated_Deployment
    cp sap-hana/documentation/SAP_Automation_on_Azure/Process_Documentation/WORKSPACES WORKSPACES/ -r
    ```

Navigate to the ~/Azure_SAP_Automated_Deployment/WORKSPACES/DEPLOYMENT-ORCHESTRATION folder.

The deployment will need the Service Principal details (application id, secret and tenant ID)

## **Preparing the region**

For deploying the supporting infrastructure for the Azure region(Deployer, Library) use the prepare_region.sh script

```bash
${DEPLOYMENT_REPO_PATH}deploy/scripts/prepare_region.sh
-d DEPLOYER/DEV-WEEU-DEP00-INFRASTRUCTURE/DEV-WEEU-DEP00-INFRASTRUCTURE.json -l LIBRARY/DEV-WEEU-SAP_LIBRARY/DEV-WEEU-SAP_LIBRARY.json
```

The script will deploy the deployment infrastructure and create the Azure keyvault for storing the Service Principal details. When prompted for the environment details enter "DEV" and then enter the Service Principal details. The script will them deploy the rest of the resources required.

## **Deploying the DEV environment**

For deploying the DEV environment (vnet & keyvaults) navigate to the folder(LANDSCAPE/DEV-WEEU-SAP01-INFRASTRUCTURE) containing the DEV-WEEU-SAP01-INFRASTRUCTURE.json parameter file and use the install_workloadzone script.

```bash
${DEPLOYMENT_REPO_PATH}deploy/scripts/install_workloadzone.sh -p DEV-WEEU-SAP01-INFRASTRUCTURE.json 
```

## **Deploying the SAP system**

For deploying the SAP system navigate to the folder(DEV-WEEU-SAP01-ZZZ) containing the DEV-WEEU-SAP01-ZZZ.json parameter file and use the installer.sh script.

```bash
${DEPLOYMENT_REPO_PATH}deploy/scripts/installer.sh -p DEV-WEEU-SAP01-ZZZ.json -t sap_system
```

