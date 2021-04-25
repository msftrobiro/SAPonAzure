variable "anchor_vm" {
  description = "Deployed anchor VM"
}

variable "resource_group" {
  description = "Details of the resource group"
}

variable "vnet_sap" {
  description = "Details of the SAP Vnet"
}

variable "storage_bootdiag_endpoint" {
  description = "Details of the boot diagnostics storage account"
}

variable "ppg" {
  description = "Details of the proximity placement group"
}

variable "naming" {
  description = "Defines the names for the resources"
}

variable "custom_disk_sizes_filename" {
  type        = string
  description = "Disk size json file"
  default     = ""
}

variable "admin_subnet" {
  description = "Information about SAP admin subnet"
}

variable "db_subnet" {
  description = "Information about SAP db subnet"
}
variable "sid_kv_user_id" {
  description = "ID of the user keyvault for sap_system"
}

variable "sdu_public_key" {
  description = "Public key used for authentication"
}

variable "sid_password" {
  description = "SDU password"
}

variable "sid_username" {
  description = "SDU username"
}

variable "sap_sid" {
  description = "The SID of the application"
}

variable "db_asg_id" {
  description = "Database Application Security Group"
}

locals {
  // Imports database sizing information


  sizes         = jsondecode(file(length(var.custom_disk_sizes_filename) > 0  ? format("%s/%s",path.cwd, var.custom_disk_sizes_filename) : format("%s%s",path.module,"/../../../../../configs/anydb_sizes.json")))
  custom_sizing = length(var.custom_disk_sizes_filename) > 0

  faults = jsondecode(file(format("%s%s",path.module,"/../../../../../configs/max_fault_domain_count.json")))

  computer_names       = var.naming.virtualmachine_names.ANYDB_COMPUTERNAME
  virtualmachine_names = var.naming.virtualmachine_names.ANYDB_VMNAME

  observer_computer_names       = var.naming.virtualmachine_names.OBSERVER_COMPUTERNAME
  observer_virtualmachine_names = var.naming.virtualmachine_names.OBSERVER_VMNAME

  storageaccount_names = var.naming.storageaccount_names.SDU
  resource_suffixes    = var.naming.resource_suffixes

  region    = try(var.infrastructure.region, "")
  anydb_sid = (length(local.anydb_databases) > 0) ? try(local.anydb.instance.sid, lower(substr(local.anydb_platform, 0, 3))) : lower(substr(local.anydb_platform, 0, 3))
  sid       = length(var.sap_sid) > 0 ? var.sap_sid : local.anydb_sid
  prefix    = try(var.infrastructure.resource_group.name, trimspace(var.naming.prefix.SDU))
  rg_name   = try(var.infrastructure.resource_group.name, format("%s%s", local.prefix, local.resource_suffixes.sdu_rg))

  //Allowing changing the base for indexing, default is zero-based indexing, if customers want the first disk to start with 1 they would change this
  offset = try(var.options.resource_offset, 0)

  //Allowing to keep the old nic order
  legacy_nic_order = try(var.options.legacy_nic_order, false)
  // Availability Set 
  availabilityset_arm_ids = try(local.anydb.avset_arm_ids, [])
  availabilitysets_exist  = length(local.availabilityset_arm_ids) > 0 ? true : false

  // Return the max fault domain count for the region
  faultdomain_count = try(tonumber(compact(
    [for pair in local.faults :
      upper(pair.Location) == upper(local.region) ? pair.MaximumFaultDomainCount : ""
  ])[0]), 2)

  // Support dynamic addressing
  use_DHCP = try(local.anydb.use_DHCP, false)

  anydb          = try(local.anydb_databases[0], {})
  anydb_platform = try(local.anydb.platform, "NONE")
  anydb_version  = try(local.anydb.db_version, "")

  // Dual network cards
  anydb_dual_nics = try(local.anydb.dual_nics, false)

  // Filter the list of databases to only AnyDB platform entries
  // Supported databases: Oracle, DB2, SQLServer, ASE 
  anydb_databases = [
    for database in var.databases : database
    if contains(["ORACLE", "DB2", "SQLSERVER", "ASE"], upper(try(database.platform, "NONE")))
  ]

  // Enable deployment based on length of local.anydb_databases
  enable_deployment = (length(local.anydb_databases) > 0) ? true : false

  // If custom image is used, we do not overwrite os reference with default value
  anydb_custom_image = try(local.anydb.os.source_image_id, "") != "" ? true : false

  anydb_ostype = upper(local.anydb_platform) == "SQLSERVER" ? "WINDOWS" : try(local.anydb.os.os_type, "LINUX")
  anydb_oscode = upper(local.anydb_ostype) == "LINUX" ? "l" : "w"
  anydb_size   = try(local.anydb.size, "Default")
  anydb_sku    = try(lookup(local.sizes, local.anydb_size).compute.vm_size, "Standard_E4s_v3")
  anydb_fs     = try(local.anydb.filesystem, "xfs")
  anydb_ha     = try(local.anydb.high_availability, false)

  db_sid       = lower(substr(local.anydb_platform, 0, 3))
  loadbalancer = try(local.anydb.loadbalancer, {})

  node_count      = try(length(var.databases[0].dbnodes), 1)
  db_server_count = local.anydb_ha ? local.node_count * 2 : local.node_count

  anydb_cred = try(local.anydb.credentials, {})

  sid_auth_type        = try(local.anydb.authentication.type, "key")
  enable_auth_password = local.enable_deployment && local.sid_auth_type == "password"
  enable_auth_key      = local.enable_deployment && local.sid_auth_type == "key"

  // Tags
  tags = try(local.anydb.tags, {})

  authentication = {
    "type"     = local.sid_auth_type
    "username" = var.sid_username
    "password" = var.sid_password
  }

  // Default values in case not provided
  os_defaults = {
    ORACLE = {
      "publisher" = "Oracle",
      "offer"     = "Oracle-Linux",
      "sku"       = "77",
      "version"   = "latest"
    }
    DB2 = {
      "publisher" = "suse",
      "offer"     = "sles-sap-12-sp5",
      "sku"       = "gen1"
      "version"   = "latest"
    }
    ASE = {
      "publisher" = "suse",
      "offer"     = "sles-sap-12-sp5",
      "sku"       = "gen1"
      "version"   = "latest"
    }
    SQLSERVER = {
      "publisher" = "MicrosoftSqlServer",
      "offer"     = "SQL2017-WS2016",
      "sku"       = "standard-gen2",
      "version"   = "latest"
    }
    NONE = {
      "publisher" = "",
      "offer"     = "",
      "sku"       = "",
      "version"   = ""
    }
  }

  anydb_os = {
    "source_image_id" = local.anydb_custom_image ? local.anydb.os.source_image_id : ""
    "publisher"       = try(local.anydb.os.publisher, local.anydb_custom_image ? "" : local.os_defaults[upper(local.anydb_platform)].publisher)
    "offer"           = try(local.anydb.os.offer, local.anydb_custom_image ? "" : local.os_defaults[upper(local.anydb_platform)].offer)
    "sku"             = try(local.anydb.os.sku, local.anydb_custom_image ? "" : local.os_defaults[upper(local.anydb_platform)].sku)
    "version"         = try(local.anydb.os.version, local.anydb_custom_image ? "" : local.os_defaults[upper(local.anydb_platform)].version)
  }

  //Observer VM
  observer                 = try(local.anydb.observer, {})
  deploy_observer          = upper(local.anydb_platform) == "ORACLE" && local.anydb_ha
  observer_size            = "Standard_D4s_v3"
  observer_authentication  = local.authentication
  observer_custom_image    = local.anydb_custom_image
  observer_custom_image_id = local.anydb_os.source_image_id
  observer_os              = local.anydb_os

  // Update database information with defaults
  anydb_database = merge(local.anydb,
    { platform = local.anydb_platform },
    { db_version = local.anydb_version },
    { size = local.anydb_size },
    { os = merge({ os_type = local.anydb_ostype }, local.anydb_os) },
    { high_availability = local.anydb_ha },
    { auth_type = local.sid_auth_type },
    { dbnodes = local.dbnodes },
    { loadbalancer = local.loadbalancer }
  )


  dbnodes = local.anydb_ha ? (
    flatten([for idx, dbnode in try(local.anydb.dbnodes, [{}]) :
      [
        {
          name         = try("${dbnode.name}-0", format("%s%s%s%s", local.prefix, var.naming.separator, local.virtualmachine_names[idx], local.resource_suffixes.vm))
          computername = try("${dbnode.name}-0", local.computer_names[idx], local.resource_suffixes.vm)
          role         = try(dbnode.role, "db")
          admin_nic_ip = lookup(dbnode, "admin_nic_ips", ["false", "false"])[0]
          db_nic_ip    = lookup(dbnode, "db_nic_ips", ["false", "false"])[0]
        },
        {
          name         = try("${dbnode.name}-1", format("%s%s%s%s", local.prefix, var.naming.separator, local.virtualmachine_names[idx + local.node_count], local.resource_suffixes.vm))
          computername = try("${dbnode.name}-1", local.computer_names[idx + local.node_count])
          role         = try(dbnode.role, "db")
          admin_nic_ip = lookup(dbnode, "admin_nic_ips", ["false", "false"])[1]
          db_nic_ip    = lookup(dbnode, "db_nic_ips", ["false", "false"])[1]
        }
      ]
    ])) : (
    flatten([for idx, dbnode in try(local.anydb.dbnodes, [{}]) : {
      name         = try("${dbnode.name}-0", format("%s%s%s%s", local.prefix, var.naming.separator, local.virtualmachine_names[idx], local.resource_suffixes.vm))
      computername = try("${dbnode.name}-0", local.computer_names[idx], local.resource_suffixes.vm)
      role         = try(dbnode.role, "db")
      admin_nic_ip = lookup(dbnode, "admin_nic_ips", ["false", "false"])[0]
      db_nic_ip    = lookup(dbnode, "db_nic_ips", ["false", "false"])[0]
      }]
    )
  )


  anydb_vms = [
    for idx, dbnode in local.dbnodes : {
      platform     = local.anydb_platform,
      name         = dbnode.name
      computername = dbnode.computername
      db_nic_ip    = dbnode.db_nic_ip
      admin_nic_ip = dbnode.admin_nic_ip
      size         = local.anydb_sku
      os           = local.anydb_ostype,
      auth_type    = local.sid_auth_type,
      sid          = var.sap_sid
    }
  ]

  // Subnet IP Offsets
  // Note: First 4 IP addresses in a subnet are reserved by Azure
  anydb_ip_offsets = {
    anydb_lb       = 4
    anydb_admin_vm = 4
    anydb_db_vm    = 5 + 1
    observer_db_vm = 5 
  }

  // Ports used for specific DB Versions
  lb_ports = {
    "ASE" = [
      "1433"
    ]
    "ORACLE" = [
      "1521"
    ]
    "DB2" = [
      "62500"
    ]
    "SQLSERVER" = [
      "59999"
    ]
    "NONE" = [
      "80"
    ]
  }

  loadbalancer_ports = flatten([
    for port in local.lb_ports[upper(local.anydb_platform)] : {
      port = tonumber(port)
    }
  ])

  db_sizing = local.enable_deployment ? local.custom_sizing ? lookup(try(local.sizes.db, local.sizes), local.anydb_size).storage : lookup(local.sizes, local.anydb_size).storage : []

  data_disk_per_dbnode = (length(local.anydb_vms) > 0) ? flatten(
    [
      for storage_type in local.db_sizing : [
        for idx, disk_count in range(storage_type.count) : {
          suffix               = format("%s%02d", storage_type.name, disk_count + local.offset)
          storage_account_type = storage_type.disk_type,
          disk_size_gb         = storage_type.size_gb,
          //The following two lines are for Ultradisks only
          disk_iops_read_write      = try(storage_type.disk-iops-read-write, null)
          disk_mbps_read_write      = try(storage_type.disk-mbps-read-write, null)
          caching                   = storage_type.caching,
          write_accelerator_enabled = storage_type.write_accelerator
          type                      = storage_type.name
          lun                       = storage_type.lun_start + idx
        }
        if !try(storage_type.growth, false)
      ]
      if storage_type.name != "os"
    ]
  ) : []

  growth_data_disk_per_dbnode = (length(local.anydb_vms) > 0) ? flatten(
    [
      for storage_type in local.db_sizing : [
        for idx, disk_count in range(storage_type.count) : {
          suffix               = format("%s%02d", storage_type.name, disk_count + local.offset)
          storage_account_type = storage_type.disk_type,
          disk_size_gb         = storage_type.size_gb,
          //The following two lines are for Ultradisks only
          disk_iops_read_write      = try(storage_type.disk-iops-read-write, null)
          disk_mbps_read_write      = try(storage_type.disk-mbps-read-write, null)
          caching                   = storage_type.caching,
          write_accelerator_enabled = storage_type.write_accelerator
          type                      = storage_type.name
          lun                       = storage_type.lun_start + idx
        }
      ]
      if try(storage_type.growth, false)
    ]
  ) : []

  all_data_disk_per_dbnode = concat(local.data_disk_per_dbnode, local.growth_data_disk_per_dbnode)

  anydb_disks = flatten([
    for vm_counter, anydb_vm in local.anydb_vms : [
      for datadisk in local.all_data_disk_per_dbnode : {
        name                      = format("%s-%s", anydb_vm.name, datadisk.suffix)
        vm_index                  = vm_counter
        caching                   = datadisk.caching
        storage_account_type      = datadisk.storage_account_type
        disk_size_gb              = datadisk.disk_size_gb
        write_accelerator_enabled = datadisk.write_accelerator_enabled
        disk_iops_read_write      = datadisk.disk_iops_read_write
        disk_mbps_read_write      = datadisk.disk_mbps_read_write
        lun                       = datadisk.lun
        type                      = datadisk.type
      }
    ]
  ])

  //Disks for Ansible
  // host: xxx, LUN: #, type: sapusr, size: #

  db_disks_ansible = flatten([for idx, vm in local.anydb_vms : [
    for idx, datadisk in local.anydb_disks :
    format("{ host: '%s', LUN: %d, type: '%s' }", vm.computername, datadisk.lun, datadisk.type)
  ]])

  enable_ultradisk = try(
    compact(
      [
        for storage in local.db_sizing : storage.disk_type == "UltraSSD_LRS" ? true : ""
      ]
    )[0],
    false
  )

  // Zones
  zones         = try(local.anydb.zones, [])
  db_zone_count = length(local.zones)

  //Ultra disk requires zonal deployment
  zonal_deployment = local.db_zone_count > 0 || local.enable_ultradisk ? true : false

  //If we deploy more than one server in zone put them in an availability set
  use_avset = !local.zonal_deployment || local.db_server_count != local.db_zone_count


  full_observer_names = flatten([for vm in local.observer_virtualmachine_names :
    format("%s%s%s%s", local.prefix, var.naming.separator, vm, local.resource_suffixes.vm)]
  )

}
