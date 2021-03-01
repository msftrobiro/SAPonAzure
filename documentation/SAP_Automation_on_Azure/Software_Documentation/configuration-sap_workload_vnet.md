<!-- TODO: 
Remove files and maintain here in documentation
deploy/terraform/run/sap_landscape/saplandscape_full.json
deploy/terraform/run/sap_landscape/saplandscape.json
-->
### <img src="../assets/images/UnicornSAPBlack256x256.png" width="64px"> SAP Deployment Automation Framework <!-- omit in toc -->
<br/><br/>

# Configuration - SAP Workload VNET <!-- omit in toc -->

<br/>

## Table of Contents <!-- omit in toc -->
<br/>

- [Parameter file construction](#parameter-file-construction)
- [Examples](#examples)
  - [Minimal (Default) input parameter JSON](#minimal-default-input-parameter-json)
  - [Complete input parameter JSON](#complete-input-parameter-json)


<br/><br/><br/><br/>

---
<br/>

# Parameter file construction

JSON structure

```
{                                                                                 <-- JSON opening tag
  "tfstate_resource_id"               : "",                                       <-- Required Parameter
  "deployer_tfstate_key"              : "",                                       <-- Required Parameter
  "infrastructure": {
    "environment"                     : "NP",                                     <-- Required Parameter
    "region"                          : "eastus2",                                <-- Required Parameter
    "resource_group": {
      "arm_id"                        : "",                                       <-- Optional
      "name"                          : ""                                        <-- Optional
    },
    "vnets": {
      "sap": {
        "arm_id"                      : "",                                       <-- Optional
        "address_space"               : "10.1.0.0/16",                            <-- Required Parameter
        "subnet_iscsi": {
          "name"                      : "",                                       <-- Optional
          "prefix"                    : "10.1.0.0/24"                             <-- Optional
        }
      }
    },
    "iscsi": {
      "iscsi_count"                   : 3,                                        <-- Optional
      "use_DHCP"                      : false                                     <-- Optional
    }
  },
  "key_vault": {
    "kv_user_id"                      : "",                                       <-- Optional
    "kv_prvt_id"                      : "",                                       <-- Optional
    "kv_sid_sshkey_prvt"              : "",                                       <-- Optional
    "kv_sid_sshkey_pub"               : "",                                       <-- Optional
    "kv_iscsi_username"               : "",                                       <-- Optional
    "kv_iscsi_sshkey_prvt"            : "",                                       <-- Optional
    "kv_iscsi_sshkey_pub"             : "",                                       <-- Optional
    "kv_iscsi_pwd"                    : ""                                        <-- Optional
  },
  "sshkey": {},                                                                   <-- Optional
  "options": {}                                                                   <-- Optional
}                                                                                 <-- JSON Closing tag
```

| Parameter                                             | Type          | Default  | Description |
| :---------------------------------------------------- | ------------- | :------- | :---------- |
| `tfstate_resource_id`                                 | **required**  | -        | This is the Azure Resource ID for the Storage Account in which the Statefiles are stored. Typically this is deployed by the SAP Library execution unit. |
| `deployer_tfstate_key`                                | **required**  | -        | <!-- TODO: --> |
| infrastructure.`environment`                          | **required**  | -        | The Environment is a 5 Character designator used for partitioning. An example of partitioning would be, PROD / NP (Production and Non-Production). Environments may also be tied to a unique SPN or Subscription. |
| infrastructure.`region`                               | **required**  | -        | This specifies the Azure Region in which to deploy. |
| infrastructure.resource_group.`arm_id`                | optional      |          | <!-- TODO: --> |
| infrastructure.vnets.sap.`arm_id`                     | optional      |          | <!-- TODO: --> |
| infrastructure.vnets.sap.`address_space`              | **required**  | -        | <!-- TODO: --> |
| infrastructure.vnets.sap.subnet_iscsi.`name`          | optional      |          | <!-- TODO: --> |
| infrastructure.vnets.sap.subnet_iscsi.`prefix`        | optional      | -        | - If specified, provisions a subnet within the VNET address space.<br/>- The CIDR should be size appropriate for the expected usage.<br/>- Recommendation /28 CIDR. Supports up to 12 servers.<!-- TODO: --> |
| infrastructure.iscsi.`iscsi_count`                    | optional      |          | <!-- TODO: --> |
| infrastructure.vnets.sap.`use_DHCP`                   | optional      |          | <!-- TODO: --> |
| key_vault.`kv_user_id`                                | optional      |          | <!-- TODO: Yunzi --> |
| key_vault.`kv_prvt_id`                                | optional      |          | <!-- TODO: Yunzi --> |
| key_vault.`kv_sid_sshkey_prvt`                        | optional      |          | <!-- TODO: Yunzi --> |
| key_vault.`kv_sid_sshkey_pub`                         | optional      |          | <!-- TODO: Yunzi --> |
| key_vault.`kv_iscsi_username`                         | optional      |          | <!-- TODO: Yunzi --> |
| key_vault.`kv_iscsi_sshkey_prvt`                      | optional      |          | <!-- TODO: Yunzi --> |
| key_vault.`kv_iscsi_sshkey_pub`                       | optional      |          | <!-- TODO: Yunzi --> |
| key_vault.`kv_iscsi_pwd`                              | optional      |          | <!-- TODO: Yunzi --> |
| sshkey.`path_to_public_key`                           | optional      |          | <!-- TODO: Yunzi --> |
| sshkey.`path_to_private_key`                          | optional      |          | <!-- TODO: Yunzi --> |
| options.`enable_secure_transfer`                      | deprecate     | true     | <!-- TODO: Yunzi --> |
| options.`enable_prometheus`                           | deprecate     |          | deprecate <!-- TODO: Yunzi --> |

<br/><br/><br/><br/>

---

<br/><br/>

# Examples
<br/>

## Minimal (Default) input parameter JSON

```
{
  "tfstate_resource_id"               : "",
  "deployer_tfstate_key"              : "",
  "infrastructure": {
    "environment"                     : "NP",
    "region"                          : "eastus2",
    "vnets": {
      "sap": {
        "address_space"               : "10.1.0.0/16"
      }
    }
  }
}
```

<br/><br/><br/>

## Complete input parameter JSON

```
{
  "tfstate_resource_id"               : "",
  "deployer_tfstate_key"              : "",
  "infrastructure": {
    "environment"                     : "NP",
    "region"                          : "eastus2",
    "resource_group": {
      "arm_id"                        : "",
      "name"                          : ""
    },
    "vnets": {
      "sap": {
        "arm_id"                      : "",
        "address_space"               : "10.1.0.0/16",
        "subnet_iscsi": {
          "name"                      : "",
          "prefix"                    : "10.1.0.0/24"
        }
      }
    },
    "iscsi": {
      "iscsi_count"                   : 3,
      "use_DHCP"                      : false
    }
  },
  "key_vault": {
    "kv_user_id"                      : "",
    "kv_prvt_id"                      : "",
    "kv_sid_sshkey_prvt"              : "",
    "kv_sid_sshkey_pub"               : "",
    "kv_iscsi_username"               : "",
    "kv_iscsi_sshkey_prvt"            : "",
    "kv_iscsi_sshkey_pub"             : "",
    "kv_iscsi_pwd"                    : ""
  },
  "sshkey": {},
  "options": {}
}
```




