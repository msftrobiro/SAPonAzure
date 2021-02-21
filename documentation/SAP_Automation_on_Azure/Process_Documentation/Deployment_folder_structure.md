# Folder design

To facilitate a DevOps approach for the automation process it is recommended that the configuration and parameter files are kept in a source control repository that the customer manages. 

The development environment should clone both the “sap-hana” repository and the customer repository into the same root folder, creating a folder structure like the one shown below:

![](Folderstructure.png)

The root folder “WORKSPACES” contains the following folders.

|Folder Name|Contains|Notes|
| :- | :- | :- |
|DEPLOYMENT-ORCHESTRATION|Configuration and template files|This is the root folder for all the systems that are managed from the deployment environment|
|CONFIGURATION|Configuration files, for example custom disk sizing|Storing the custom configuration files in a shared folder simplifies referring to them|
|DEPLOYER|Contains the configuration files for all Deployer deployments managed by the deployment environment|<p>Each subfolder should be named according to the naming standard “Environment-region-Virtual Network”</p><p></p>|
|LIBRARY|Contains the configuration files for all Library deployments managed by the deployment environment|Each subfolder should be named according to the naming standard “Environment-region”|
|LANDSCAPE|Contains the configuration files for all Landscape deployments managed by the deployment environment|Each subfolder should be named according to the naming standard “Environment-region-Virtual Network”|
|SYSTEM |Contains the configuration files for all System (SID) deployments managed by the deployment environment|Each subfolder should be named according to the naming standard “Environment-region-Virtual Network-SID”|

## Deployment scripts

The repository contains two sets of orchestration scripts, one for bash and one for PowerShell. These scripts assume that the configuration files are stored using the structure specified above.

### bash based orchestration scripts

The repository contains scripts for bootstrapping the deployer, bootstrapping the library, and a generic deployment script that can be used to deploy and of the systems. 

#### Requirements

The following two environment variables need to be exported:

|Environment Variable|Description|
| :- | :- |
|ARM\_SUBSCRIPTION\_ID|Specifies the subscription to use for the deployment|
|DEPLOYMENT\_REPO\_PATH|Specifies the path to the “sap-hana” folder containing the cloned repository.|

### **install\_deployer.sh**
This script bootstraps the deployer.

Usage:
```bash
${DEPLOYMENT\_REPO\_PATH}scripts/install\_deployer.sh

Parameters:

-p parameter file for the deployer
-h show help
```

Example:

```bash
${DEPLOYMENT\_REPO\_PATH}scripts/install\_deployer.sh -p DEPLOYER/PROD-WEEU-DEP00-INFRASTRUCTURE/ PROD-WEEU-DEP00-INFRASTRUCTURE.json
```

### **install\_library.sh**

This script bootstraps the deployer.

Usage:

```bash
${DEPLOYMENT\_REPO\_PATH}scripts/install\_library.sh

Parameters:

-p parameter file for the library
-d relative path to the deployer folder (relative from the library parameter file)
-h show help
```

Example:

```bash
${DEPLOYMENT\_REPO\_PATH}scripts/install\_library.sh 
-p LIBRARY/PROD-WEEU-SAP\_LIBRARY/ PROD-WEEU-SAP\_LIBRARY.json
-d ../../DEPLOYER/PROD-WEEU-DEP00-INFRASTRUCTURE/ 
```

### **install\_environment.sh**

Wrapper script that:

1. Bootstraps the deployer
2. Set the SPN secrets
3. Bootstraps the library
4. Migrates the state of the deployer to Azure
5. Migrates the state of the library to Azure
6. Deploys the environment

Usage:

```bash
${DEPLOYMENT\_REPO\_PATH}scripts/install\_environment.sh

Parameters:
-d deployer parameter file
-l library parameter file
-e environment parameter file
-h show help
```

Example

```bash
${DEPLOYMENT\_REPO\_PATH}scripts/install\_environment.sh 
-d DEPLOYER/PROD-WEEU-DEP00-INFRASTRUCTURE/PROD-WEEU-DEP00-INFRASTRUCTURE.json \
-l LIBRARY/PROD-WEEU-SAP\_LIBRARY/PROD-WEEU-SAP\_LIBRARY.json \
-e LANDSCAPE/PROD-WEEU-SAP00-INFRASTRUCTURE/PROD-WEEU-SAP00-INFRASTRUCTURE.json
```

### **installer.sh**

Deployment helper, the script can be used to deploy the deployer, the library, the landscape or the system (SID)

Usage:

```bash
${DEPLOYMENT\_REPO\_PATH}scripts/installer.sh

Parameters:
-p parameter file
-t type of system to deploy
-h show help
```

Example:

```bash
${DEPLOYMENT\_REPO\_PATH}scripts/installer.sh
-p SYSTEM/PROD-WEEU-SAP00-ABC / PROD-WEEU-SAP00-ABC.json \
-t sap\_system
```

### **set\_secret.sh**

Helper script to set the SPN secrets in Azure keyvault.

Usage:

```bash
${DEPLOYMENT\_REPO\_PATH}scripts/set\_secret.sh

Parameters:
-e environment name
-v vault name
-c SPN app id
-s SPN password
-t tenant id
-i true/false. If true runs in interactive mode prompting for input
-h Show help
```

Example:

```bash
set\_secret.sh
-e PROD
-v prodweeuusrabc
-c 11111111-1111-1111-1111-111111111111
-s SECRETPassword
-t 222222222-2222-2222-2222-222222222222
```

## PowerShell based orchestration cmdlets

The repository contains a PowerShell module for bootstrapping the deployer, bootstrapping the library, and a generic deployment script that can be used to deploy and of the systems. 

### Installation

Create a new folder named “SAPDeploymentUtilities” in the “PowerShell\Modules” folder (located in the Documents folder)

Copy the contents of the pwsh folder from the repository’s deploy\scripts\pwsh folder to that folder. 

Open a Powershell prompt and run the:

```Powershell
Import-Module SAPDeploymentUtilities.psd1
```

### **New-Deployer**

This cmdlet bootstraps the deployer.

Usage:

```Powershell
New-Deployer -Parameterfile <>

Parameters:
-Parameterfile parameter file for the deployer
```

Help:

```Powershell
Get-Help New-Deployer -Examples
```

### **New-Library**

This cmdlet bootstraps the deployer.

Usage:

```Powershell
New-Library -Parameterfile <> -DeployerFolderRelativePath <>

Parameters:
-Parameterfile This is the parameter file for the library
-DeployerFolderRelativePath This is relative path to the deployer folder (relative from the library parameter file)
```

Example:

```Powershell
New-Library -Parameterfile .\PROD-WEEU-SAP\_LIBRARY.json -DeployerFolderRelativePath ..\..\DEPLOYER\PROD-WEEU-DEP00-INFRASTRUCTURE\
```

Help:

```Powershell
Get-Help New-Library -Examples
```

### **New-environment**

Wrapper cmdlet that deploys a new SAP Environment (Deployer, Library and Workload VNet), using the following steps:

1. Bootstrap the deployer.
2. Set the SPN secrets.
3. Bootstrap the library.
4. Migrates the state of the deployer to Azure.
5. Migrates the state of the library to Azure.
6. Deploy the environment.

Usage:

```Powershell
New-Environment -DeployerParameterfile <> -LibraryParameterfile <>
`     `-EnvironmentParameterfile <>

Parameters:
-DeployerParameterfile This is the parameter file for the Deployer
-LibraryParameterfile This is the parameter file for the Library
-EnvironmentParameterfile This is the parameter file for the workload vnet
```

Example:

```Powershell
New-Environment -DeployerParameterfile .\DEPLOYER\PROD-WEEU-DEP00-INFRASTRUCTURE\PROD-WEEU-DEP00-INFRASTRUCTURE.json`-LibraryParameterfile .LIBRARY\PROD-WEEU-SAP\_LIBRARY\PROD-WEEU-SAP\_LIBRARY.json -EnvironmentParameterfile .\LANDSCAPE\PROD-WEEU-SAP00-INFRASTRUCTURE\PROD-WEEU-SAP00-INFRASTRUCTURE.json
```

Help:

```Powershell
Get-Help New-Environment -Examples
```

### **New-System**

Deployment helper, the cmdlet can be used to deploy the deployer, the library, the landscape or the system (SID)

Usage:

```Powershell
$New-System -Parameterfile <> -Type <>

Parameters:
-Parameterfile This is the parameter file for the system
-Type Is the type of system to deploy (sap\_deployer, sap\_library, sap\_landscape, sap\_system)
```

Example:

```Powershell
$New-System -Parameterfile SYSTEM/PROD-WEEU-SAP00-ABC / PROD-WEEU-SAP00-ABC.json -Type sap\_system
```

### **Set-secrets**

Helper cmdlet to set the SPN secrets in Azure keyvault.

Usage:

```Powershell
Set-Secrets -Environment <> -VaultName <vaultname> -Client\_id <appId> -Client\_secret <clientsecret> -Tenant <TenantID> 

Parameters:
-Environment environment name
-VaultName vault name
-Client\_id SPN app id
-Client\_secret SPN password
-Tenant tenant id of the SPN
```

Example:

```Powershell
Set-Secrets -Environment PROD -VaultName prodweeuusrabc -Client\_id 11111111-1111-1111-1111-111111111111 -Client\_secret SECRETPassword -Tenant 222222222-2222-2222-2222-222222222222
```
