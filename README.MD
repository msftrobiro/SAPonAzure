# ![SAP Deployment Automation Framework](/documentation/SAP_Automation_on_Azure/assets/images/UnicornSAPBlack64x64.png) **SAP Deployment Automation Framework** #

Welcome to the [**SAP on Azure Deployment Automation Framework**](documentation/SAP_Automation_on_Azure/table_of_contents.md) repository.

This repository contains the tooling designed to enable automated deployment for SAP on Azure. The automation framework leverages [Terraform](https://www.terraform.io/) for the infrastructure deployment and [Ansible](https://www.ansible.com/) for operating system and application configuration. It allows for deployment of the infrastructure for SAP landscapes based on SAP HANA and NetWeaver with AnyDB using all SAP supported operating system versions. All SAP tiers – SBX, DEV, QA, PROD can be deployed in a chosen region.

The deployment framework is based on Microsoft best practices and principles for SAP on Azure. These principles are outlined in a comprehensive documentation which should be followed to ensure supportability by using certified virtual machines and storage solutions, stability, reliability and performance. [Get started with SAP on Azure VMs - Azure Virtual Machines | Microsoft Docs](https://docs.microsoft.com/azure/virtual-machines/workloads/sap/get-started)

The principles of the SAP Automation frameworks adhers to the principles of the Microsoft cloud adoption framework. [Microsoft Cloud Adoption Framework for Azure - Cloud Adoption Framework | Microsoft Docs](https://docs.microsoft.com/azure/cloud-adoption-framework/)

## SAP Deployment Automation Framework - Process ##

The highlevel process for deployment is illustrated in the diagram below.

![SAP Deployment Automation Framework - Process](/documentation/images/SAP-Automation_Process.png)


### Deployment environment ###

The first deployment activity is to prepare the deployment environment. This environment will contain a Virtual machine that can be used to run Terraform and Ansible. The environment will also contain a keyvault for storing credential information.

![SAP Deployment Automation Framework - Process](/documentation/images/deployer.png)



Please review to glossary which helps to understand the deployment structure: [Glossary](documentation/SAP_Automation_on_Azure/Process_Documentation/glossary.md)

Deployment steps and pre-deployment requirements can be found here: [SAP Automation on Azure](documentation/SAP_Automation_on_Azure)

Product Documentation is documented here, this is for information purposes and should not be changed.

[sap-hana/documentation/SAP_Automation_on_Azure/Software_Documentation at beta · Azure/sap-hana · GitHub](https://github.com/Azure/sap-hana/tree/beta/documentation/SAP_Automation_on_Azure/Software_Documentation)


For information about how to collaborate in the repo please see the [contributing guidelines](CONTRIBUTING.md)


Post-deployment activities like system copies tbd
