
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

variable "storage_subnet" {
  description = "Information about storage subnet"
}

variable "sid_kv_user_id" {
  description = "Details of the user keyvault for sap_system"
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
  // Resources naming
  computer_names       = var.naming.virtualmachine_names.HANA_COMPUTERNAME
  virtualmachine_names = var.naming.virtualmachine_names.HANA_VMNAME

  storageaccount_names = var.naming.storageaccount_names.SDU
  resource_suffixes    = var.naming.resource_suffixes

  // Imports database sizing information
  sizes         = jsondecode(file(length(var.custom_disk_sizes_filename) > 0  ? format("%s/%s",path.cwd, var.custom_disk_sizes_filename) : format("%s%s",path.module,"/../../../../../configs/hdb_sizes.json")))
  custom_sizing = length(var.custom_disk_sizes_filename) > 0

  faults = jsondecode(file(format("%s%s",path.module,"/../../../../../configs/max_fault_domain_count.json")))

  region = try(var.infrastructure.region, "")
  sid    = upper(var.sap_sid)
  prefix = try(var.infrastructure.resource_group.name, trimspace(var.naming.prefix.SDU))

  rg_name = try(var.infrastructure.resource_group.name, format("%s%s", local.prefix, local.resource_suffixes.sdu_rg))

  //Allowing changing the base for indexing, default is zero-based indexing, if customers want the first disk to start with 1 they would change this
  offset = try(var.options.resource_offset, 0)

  hdb_list = [
    for db in var.databases : db
    if try(db.platform, "NONE") == "HANA"
  ]

  enable_deployment = (length(local.hdb_list) > 0) ? true : false

  // Filter the list of databases to only HANA platform entries
  hdb = try(local.hdb_list[0], {})

  //ANF support
  use_ANF = try(local.hdb.use_ANF, false)
  //Scalout subnet is needed if ANF is used and there are more than one hana node 
  dbnode_per_site       = length(try(local.hdb.dbnodes, [{}]))
  enable_storage_subnet = local.use_ANF && local.dbnode_per_site > 1

  // Availability Set 
  availabilityset_arm_ids = try(local.hdb.avset_arm_ids, [])
  availabilitysets_exist  = length(local.availabilityset_arm_ids) > 0 ? true : false

  // Return the max fault domain count for the region
  faultdomain_count = try(tonumber(compact(
    [for pair in local.faults :
      upper(pair.Location) == upper(local.region) ? pair.MaximumFaultDomainCount : ""
  ])[0]), 2)

  // Tags
  tags = try(local.hdb.tags, {})

  // Support dynamic addressing
  use_DHCP = try(local.hdb.use_DHCP, false)

  hdb_platform = try(local.hdb.platform, "NONE")
  hdb_version  = try(local.hdb.db_version, "2.00.043")
  // If custom image is used, we do not overwrite os reference with default value
  hdb_custom_image = try(local.hdb.os.source_image_id, "") != "" ? true : false
  hdb_os = {
    "source_image_id" = local.hdb_custom_image ? local.hdb.os.source_image_id : ""
    "publisher"       = try(local.hdb.os.publisher, local.hdb_custom_image ? "" : "suse")
    "offer"           = try(local.hdb.os.offer, local.hdb_custom_image ? "" : "sles-sap-12-sp5")
    "sku"             = try(local.hdb.os.sku, local.hdb_custom_image ? "" : "gen1")
    "version"         = try(local.hdb.os.sku, local.hdb_custom_image ? "" : "latest")
  }

  hdb_size = try(local.hdb.size, "Default")
  hdb_fs   = try(local.hdb.filesystem, "xfs")
  hdb_ha   = try(local.hdb.high_availability, false)

  sid_auth_type        = try(local.hdb.authentication.type, "key")
  enable_auth_password = local.enable_deployment && local.sid_auth_type == "password"
  enable_auth_key      = local.enable_deployment && local.sid_auth_type == "key"

  hdb_auth = {
    "type"     = local.sid_auth_type
    "username" = var.sid_username
    "password" = var.sid_password
  }

  node_count      = try(length(local.hdb.dbnodes), 1)
  db_server_count = local.hdb_ha ? local.node_count * 2 : local.node_count

  hdb_ins    = try(local.hdb.instance, {})
  hdb_sid    = try(local.hdb_ins.sid, local.sid) // HANA database sid from the Databases array for use as reference to LB/AS
  hdb_nr     = try(local.hdb_ins.instance_number, "01")
  components = merge({ hana_database = [] }, try(local.hdb.components, {}))
  xsa        = try(local.hdb.xsa, { routing = "ports" })
  shine      = try(local.hdb.shine, { email = "shinedemo@microsoft.com" })

  dbnodes = local.hdb_ha ? (
    flatten([for idx, dbnode in try(local.hdb.dbnodes, [{}]) :
      [
        {
          name           = try("${dbnode.name}-0", format("%s%s%s%s", local.prefix, var.naming.separator, local.virtualmachine_names[idx], local.resource_suffixes.vm))
          computername   = try("${dbnode.name}-0", local.computer_names[idx], local.resource_suffixes.vm)
          role           = try(dbnode.role, "worker")
          admin_nic_ip   = lookup(dbnode, "admin_nic_ips", [false, false])[0]
          db_nic_ip      = lookup(dbnode, "db_nic_ips", [false, false])[0]
          storage_nic_ip = lookup(dbnode, "storage_nic_ips", [false, false])[0]
        },
        {
          name           = try("${dbnode.name}-1", format("%s%s%s%s", local.prefix, var.naming.separator, local.virtualmachine_names[idx + local.node_count], local.resource_suffixes.vm))
          computername   = try("${dbnode.name}-1", local.computer_names[idx + local.node_count])
          role           = try(dbnode.role, "worker")
          admin_nic_ip   = lookup(dbnode, "admin_nic_ips", [false, false])[1]
          db_nic_ip      = lookup(dbnode, "db_nic_ips", [false, false])[1]
          storage_nic_ip = lookup(dbnode, "storage_nic_ips", [false, false])[1]
        }
      ]
    ])) : (
    flatten([for idx, dbnode in try(local.hdb.dbnodes, [{}]) : {
      name           = try("${dbnode.name}-0", format("%s%s%s%s", local.prefix, var.naming.separator, local.virtualmachine_names[idx], local.resource_suffixes.vm))
      computername   = try("${dbnode.name}-0", local.computer_names[idx], local.resource_suffixes.vm)
      role           = try(dbnode.role, "worker")
      admin_nic_ip   = lookup(dbnode, "admin_nic_ips", [false, false])[0]
      db_nic_ip      = lookup(dbnode, "db_nic_ips", [false, false])[0]
      storage_nic_ip = lookup(dbnode, "storage_nic_ips", [false, false])[0]
      }]
    )
  )

  loadbalancer = try(local.hdb.loadbalancer, {})

  // Update HANA database information with defaults
  hana_database = merge(local.hdb,
    { platform = local.hdb_platform },
    { db_version = local.hdb_version },
    { os = local.hdb_os },
    { size = local.hdb_size },
    { high_availability = local.hdb_ha },
    { auth_type = local.sid_auth_type },
    { dbnodes = local.dbnodes },
    { loadbalancer = local.loadbalancer },
    { instance = {
      sid             = local.hdb_sid,
      instance_number = local.hdb_nr
      }
    }
  )

  // Numerically indexed Hash of HANA DB nodes to be created
  hdb_vms = [
    for idx, dbnode in local.dbnodes : {
      platform       = local.hdb_platform,
      name           = dbnode.name
      computername   = dbnode.computername
      admin_nic_ip   = dbnode.admin_nic_ip,
      db_nic_ip      = dbnode.db_nic_ip,
      storage_nic_ip = dbnode.storage_nic_ip,
      size           = local.hdb_size,
      os             = local.hdb_os,
      auth_type      = local.sid_auth_type,
      sid            = local.hdb_sid

    }
  ]

  // Subnet IP Offsets
  // Note: First 4 IP addresses in a subnet are reserved by Azure
  hdb_ip_offsets = {
    hdb_lb         = 4
    hdb_admin_vm   = 4
    hdb_db_vm      = 5
    hdb_storage_vm = 4
  }

  // Ports used for specific HANA Versions
  lb_ports = {
    "1" = [
      "30015",
      "30017",
    ]

    "2" = [
      "30013",
      "30014",
      "30015",
      "30040",
      "30041",
      "30042",
    ]
  }

  loadbalancer_ports = flatten([
    for port in local.lb_ports[split(".", local.hdb_version)[0]] : {
      sid  = var.sap_sid
      port = tonumber(port) + (tonumber(local.hana_database.instance.instance_number) * 100)
    }
  ])



  db_sizing = local.enable_deployment ? local.custom_sizing ? lookup(try(local.sizes.db, local.sizes), local.hdb_size).storage : lookup(local.sizes, local.hdb_size).storage : []

  // List of data disks to be created for HANA DB nodes
  data_disk_per_dbnode = (length(local.hdb_vms) > 0) && local.enable_deployment ? flatten(
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


  growth_disk_per_dbnode = (length(local.hdb_vms) > 0) && local.enable_deployment ? flatten(
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

  all_data_disk_per_dbnode = concat(local.data_disk_per_dbnode, local.growth_disk_per_dbnode)

  data_disk_list = flatten([
    for vm_counter, hdb_vm in local.hdb_vms : [
      for datadisk in local.all_data_disk_per_dbnode : {
        name                      = format("%s-%s", hdb_vm.name, datadisk.suffix)
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

  db_disks_ansible = flatten([for idx, vm in local.hdb_vms : [
    for idx, datadisk in local.data_disk_list :
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
  zones         = try(local.hdb.zones, [])
  db_zone_count = length(local.zones)

  //Ultra disk requires zonal deployment
  zonal_deployment = local.db_zone_count > 0 || local.enable_ultradisk ? true : false

  //If we deploy more than one server in zone put them in an availability set
  use_avset = !local.zonal_deployment || local.db_server_count != local.db_zone_count

}
