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
