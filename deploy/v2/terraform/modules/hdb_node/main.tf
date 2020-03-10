##################################################################################################################
# HANA DB Node
##################################################################################################################

# NETWORK SECURITY RULES =========================================================================================

# Creates network security rule to deny external traffic for SAP admin subnet
resource "azurerm_network_security_rule" "nsr-admin" {
  count                       = var.infrastructure.vnets.sap.subnet_admin.nsg.is_existing ? 0 : 1
  name                        = "deny-inbound-traffic"
  resource_group_name         = var.nsg-admin[0].resource_group_name
  network_security_group_name = var.nsg-admin[0].name
  priority                    = 102
  direction                   = "Inbound"
  access                      = "deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = var.infrastructure.vnets.sap.subnet_admin.prefix
}

# Creates network security rule for SAP DB subnet
resource "azurerm_network_security_rule" "nsr-db" {
  count                       = var.infrastructure.vnets.sap.subnet_db.nsg.is_existing ? 0 : 1
  name                        = "nsr-subnet-db"
  resource_group_name         = var.nsg-db[0].resource_group_name
  network_security_group_name = var.nsg-db[0].name
  priority                    = 102
  direction                   = "Inbound"
  access                      = "allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.infrastructure.vnets.management.subnet_mgmt.prefix
  destination_address_prefix  = var.infrastructure.vnets.sap.subnet_db.prefix
}

# NICS ============================================================================================================

# Creates the admin traffic NIC and private IP address for database nodes
resource "azurerm_network_interface" "nics-dbnodes-admin" {
  for_each                      = local.dbnodes
  name                          = "${each.value.name}-admin-nic"
  location                      = var.resource-group[0].location
  resource_group_name           = var.resource-group[0].name
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "${each.value.name}-admin-nic-ip"
    subnet_id                     = var.subnet-sap-admin[0].id
    private_ip_address            = var.infrastructure.vnets.sap.subnet_admin.is_existing ? each.value.admin_nic_ip : lookup(each.value, "admin_nic_ip", false) != false ? each.value.admin_nic_ip : cidrhost(var.infrastructure.vnets.sap.subnet_admin.prefix, tonumber(each.key) + 4)
    private_ip_address_allocation = "static"
  }
}

# Creates the DB traffic NIC and private IP address for database nodes
resource "azurerm_network_interface" "nics-dbnodes-db" {
  for_each                      = local.dbnodes
  name                          = "${each.value.name}-db-nic"
  location                      = var.resource-group[0].location
  resource_group_name           = var.resource-group[0].name
  enable_accelerated_networking = true

  ip_configuration {
    primary                       = true
    name                          = "${each.value.name}-db-nic-ip"
    subnet_id                     = var.subnet-sap-db[0].id
    private_ip_address            = var.infrastructure.vnets.sap.subnet_db.is_existing ? each.value.db_nic_ip : lookup(each.value, "db_nic_ip", false) != false ? each.value.db_nic_ip : cidrhost(var.infrastructure.vnets.sap.subnet_db.prefix, tonumber(each.key) + 4)
    private_ip_address_allocation = "static"
  }
}

# tag: azurerm 2.0.0
# Manages the association between NIC and NSG.
resource "azurerm_network_interface_security_group_association" "nic-dbnodes-admin-nsg" {
  for_each                  = local.dbnodes
  network_interface_id      = azurerm_network_interface.nics-dbnodes-admin[each.key].id
  network_security_group_id = var.nsg-admin[0].id
}

resource "azurerm_network_interface_security_group_association" "nic-dbnodes-db-nsg" {
  for_each                  = local.dbnodes
  network_interface_id      = azurerm_network_interface.nics-dbnodes-db[each.key].id
  network_security_group_id = var.nsg-db[0].id
}

# tag: azurerm 2.0.0
# Create managed data disk
resource "azurerm_managed_disk" "data-disk" {
  count                = length(local.data-disk-list)
  name                 = local.data-disk-list[count.index].name
  location             = var.resource-group[0].location
  resource_group_name  = var.resource-group[0].name
  create_option        = "Empty"
  storage_account_type = local.data-disk-list[count.index].storage_account_type
  disk_size_gb         = local.data-disk-list[count.index].disk_size_gb
}

# VIRTUAL MACHINES ================================================================================================

# tag: azurerm 2.0.0
# Manages Linux Virtual Machine for HANA DB servers
resource "azurerm_linux_virtual_machine" "vm-dbnode" {
  for_each            = local.dbnodes
  name                = each.value.name
  computer_name       = each.value.name
  location            = var.resource-group[0].location
  resource_group_name = var.resource-group[0].name
  network_interface_ids = [
    azurerm_network_interface.nics-dbnodes-admin[each.key].id,
    azurerm_network_interface.nics-dbnodes-db[each.key].id
  ]
  size                            = lookup(local.sizes, each.value.size).compute.vm_size
  admin_username                  = each.value.authentication.username
  admin_password                  = lookup(each.value.authentication, "password", null)
  disable_password_authentication = each.value.authentication.type != "password" ? true : false

  dynamic "os_disk" {
    iterator = disk
    for_each = flatten([for storage_type in lookup(local.sizes, each.value.size).storage : [for disk_count in range(storage_type.count) : { name = storage_type.name, id = disk_count, disk_type = storage_type.disk_type, size_gb = storage_type.size_gb, caching = storage_type.caching }] if storage_type.name == "os"])
    content {
      name                 = "${each.value.name}-osdisk"
      caching              = disk.value.caching
      storage_account_type = disk.value.disk_type
      disk_size_gb         = disk.value.size_gb
    }
  }

  source_image_reference {
    publisher = each.value.os.publisher
    offer     = each.value.os.offer
    sku       = each.value.os.sku
    version   = "latest"
  }

  admin_ssh_key {
    username   = each.value.authentication.username
    public_key = file(var.sshkey.path_to_public_key)
  }

  boot_diagnostics {
    storage_account_uri = var.storage-bootdiag.primary_blob_endpoint
  }
}

# tag: azurerm 2.0.0
# Manages attaching a Disk to a Virtual Machine
resource "azurerm_virtual_machine_data_disk_attachment" "vm-dbnode-data-disk" {
  count                     = length(local.data-disk-list)
  managed_disk_id           = azurerm_managed_disk.data-disk[count.index].id
  virtual_machine_id        = azurerm_linux_virtual_machine.vm-dbnode[floor(count.index / length(local.data-disk-list))].id
  caching                   = local.data-disk-list[count.index].caching
  write_accelerator_enabled = local.data-disk-list[count.index].write_accelerator_enabled
  lun                       = count.index
}
