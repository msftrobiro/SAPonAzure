/*-----------------------------------------------------------------------------8
|                                                                              |
|                                 HANA - VMs                                   |
|                                                                              |
+--------------------------------------4--------------------------------------*/

# NICS ============================================================================================================

/*-----------------------------------------------------------------------------8
HANA DB Linux Server private IP range: .10 -
+--------------------------------------4--------------------------------------*/

# Creates the admin traffic NIC and private IP address for database nodes
resource "azurerm_network_interface" "nics_dbnodes_admin" {
  provider = azurerm.main
  count    = local.enable_deployment ? length(local.hdb_vms) : 0
  name     = format("%s%s", local.hdb_vms[count.index].name, local.resource_suffixes.admin_nic)

  location                      = var.resource_group[0].location
  resource_group_name           = var.resource_group[0].name
  enable_accelerated_networking = true

  ip_configuration {
    name      = "ipconfig1"
    subnet_id = var.admin_subnet.id
    private_ip_address = local.use_DHCP ? (
      null) : (
      lookup(local.hdb_vms[count.index], "admin_nic_ip", false) != false ? (
        local.hdb_vms[count.index].admin_nic_ip) : (
        cidrhost(var.admin_subnet.address_prefixes[0], tonumber(count.index) + local.hdb_ip_offsets.hdb_admin_vm)
      )
    )

    private_ip_address_allocation = local.use_DHCP ? "Dynamic" : "Static"
  }
}

# Creates the DB traffic NIC and private IP address for database nodes
resource "azurerm_network_interface" "nics_dbnodes_db" {
  provider = azurerm.main
  count    = local.enable_deployment ? length(local.hdb_vms) : 0
  name     = format("%s%s", local.hdb_vms[count.index].name, local.resource_suffixes.db_nic)

  location                      = var.resource_group[0].location
  resource_group_name           = var.resource_group[0].name
  enable_accelerated_networking = true

  ip_configuration {
    primary   = true
    name      = "ipconfig1"
    subnet_id = var.db_subnet.id

    private_ip_address = local.use_DHCP ? (
      null) : (
      try(local.hdb_vms[count.index].db_nic_ip, false) != false ? (
        local.hdb_vms[count.index].db_nic_ip) : (
        cidrhost(var.db_subnet.address_prefixes[0], tonumber(count.index) + local.hdb_ip_offsets.hdb_db_vm)
      )
    )
    private_ip_address_allocation = local.use_DHCP ? "Dynamic" : "Static"
  }
}

resource "azurerm_network_interface_application_security_group_association" "db" {
  provider                      = azurerm.main
  count                         = local.enable_deployment ? length(local.hdb_vms) : 0
  network_interface_id          = azurerm_network_interface.nics_dbnodes_db[count.index].id
  application_security_group_id = var.db_asg_id
}


// Creates the NIC for Hana storage
resource "azurerm_network_interface" "nics_dbnodes_storage" {
  provider = azurerm.main
  count    = local.enable_deployment && local.enable_storage_subnet ? length(local.hdb_vms) : 0
  name     = format("%s%s", local.hdb_vms[count.index].name, local.resource_suffixes.storage_nic)

  location                      = var.resource_group[0].location
  resource_group_name           = var.resource_group[0].name
  enable_accelerated_networking = true

  ip_configuration {
    primary   = true
    name      = "ipconfig1"
    subnet_id = var.storage_subnet.id

    private_ip_address = local.use_DHCP ? null : try(local.hdb_vms[count.index].scaleout_nic_ip, false) != false ? (
      local.hdb_vms[count.index].scaleout_nic_ip) : (
      cidrhost(var.storage_subnet[0].address_prefixes[0], tonumber(count.index) + local.hdb_ip_offsets.hdb_scaleout_vm)

    )
    private_ip_address_allocation = local.use_DHCP ? "Dynamic" : "Static"
  }
}

# VIRTUAL MACHINES ================================================================================================

# Manages Linux Virtual Machine for HANA DB servers
resource "azurerm_linux_virtual_machine" "vm_dbnode" {
  provider            = azurerm.main
  depends_on          = [var.anchor_vm]
  count               = local.enable_deployment ? length(local.hdb_vms) : 0
  name                = local.hdb_vms[count.index].name
  computer_name       = local.hdb_vms[count.index].computername
  location            = var.resource_group[0].location
  resource_group_name = var.resource_group[0].name

  proximity_placement_group_id = local.zonal_deployment ? var.ppg[count.index % max(local.db_zone_count, 1)].id : var.ppg[0].id

  //If more than one servers are deployed into a single zone put them in an availability set and not a zone
  availability_set_id = local.use_avset ? (
    local.availabilitysets_exist ? (
      data.azurerm_availability_set.hdb[count.index % max(local.db_zone_count, 1)].id) : (
      azurerm_availability_set.hdb[count.index % max(local.db_zone_count, 1)].id
    )
  ) : null
  zone = local.use_avset ? null : local.zones[count.index % max(local.db_zone_count, 1)]

  network_interface_ids = local.enable_storage_subnet ? ([
    azurerm_network_interface.nics_dbnodes_db[count.index].id,
    azurerm_network_interface.nics_dbnodes_admin[count.index].id,
    azurerm_network_interface.nics_dbnodes_storage[count.index].id]) : ([
    azurerm_network_interface.nics_dbnodes_db[count.index].id,
    azurerm_network_interface.nics_dbnodes_admin[count.index].id]
  )
  size                            = lookup(try(local.sizes.db, local.sizes), local.hdb_vms[count.index].size).compute.vm_size
  admin_username                  = var.sid_username
  admin_password                  = local.enable_auth_key ? null : var.sid_password
  disable_password_authentication = !local.enable_auth_password

  dynamic "os_disk" {
    iterator = disk
    for_each = flatten([for storage_type in lookup(try(local.sizes.db, local.sizes), local.hdb_vms[count.index].size).storage : [for disk_count in range(storage_type.count) : { name = storage_type.name, id = disk_count, disk_type = storage_type.disk_type, size_gb = storage_type.size_gb, caching = storage_type.caching }] if storage_type.name == "os"])
    content {
      name                   = format("%s%s", local.hdb_vms[count.index].name, local.resource_suffixes.osdisk)
      caching                = disk.value.caching
      storage_account_type   = disk.value.disk_type
      disk_size_gb           = disk.value.size_gb
      disk_encryption_set_id = try(var.options.disk_encryption_set_id, null)
    }
  }

  source_image_id = local.hdb_vms[count.index].os.source_image_id != "" ? local.hdb_vms[count.index].os.source_image_id : null

  # If source_image_id is not defined, deploy with source_image_reference
  dynamic "source_image_reference" {
    for_each = range(local.hdb_vms[count.index].os.source_image_id == "" ? 1 : 0)
    content {
      publisher = local.hdb_vms[count.index].os.publisher
      offer     = local.hdb_vms[count.index].os.offer
      sku       = local.hdb_vms[count.index].os.sku
      version   = local.hdb_vms[count.index].os.version
    }
  }

  dynamic "admin_ssh_key" {
    for_each = range(local.enable_auth_password ? 0 : 1)
    content {
      username   = var.sid_username
      public_key = var.sdu_public_key
    }
  }

  additional_capabilities {
    ultra_ssd_enabled = local.enable_ultradisk
  }

  boot_diagnostics {
    storage_account_uri = var.storage_bootdiag_endpoint
  }

  tags = local.tags
}

# Creates managed data disk
resource "azurerm_managed_disk" "data_disk" {
  provider               = azurerm.main
  count                  = local.enable_deployment ? length(local.data_disk_list) : 0
  name                   = local.data_disk_list[count.index].name
  location               = var.resource_group[0].location
  resource_group_name    = var.resource_group[0].name
  create_option          = "Empty"
  storage_account_type   = local.data_disk_list[count.index].storage_account_type
  disk_size_gb           = local.data_disk_list[count.index].disk_size_gb
  disk_encryption_set_id = try(var.options.disk_encryption_set_id, null)

  zones = local.enable_ultradisk || local.db_server_count == local.db_zone_count ? (
    [azurerm_linux_virtual_machine.vm_dbnode[local.data_disk_list[count.index].vm_index].zone]) : (
    null
  )
}

# Manages attaching a Disk to a Virtual Machine
resource "azurerm_virtual_machine_data_disk_attachment" "vm_dbnode_data_disk" {
  provider                  = azurerm.main
  count                     = local.enable_deployment ? length(local.data_disk_list) : 0
  managed_disk_id           = azurerm_managed_disk.data_disk[count.index].id
  virtual_machine_id        = azurerm_linux_virtual_machine.vm_dbnode[local.data_disk_list[count.index].vm_index].id
  caching                   = local.data_disk_list[count.index].caching
  write_accelerator_enabled = local.data_disk_list[count.index].write_accelerator_enabled
  lun                       = local.data_disk_list[count.index].lun
}
