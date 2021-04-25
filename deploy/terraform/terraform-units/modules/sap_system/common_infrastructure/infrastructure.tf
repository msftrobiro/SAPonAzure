// Creates the resource group
resource "azurerm_resource_group" "resource_group" {
  provider = azurerm.main
  count    = local.rg_exists ? 0 : 1
  name     = local.rg_name
  location = local.region
}

// Imports data of existing resource group
data "azurerm_resource_group" "resource_group" {
  provider = azurerm.main
  count    = local.rg_exists ? 1 : 0
  name     = local.rg_name
}

// Imports data of Landscape SAP VNET
data "azurerm_virtual_network" "vnet_sap" {
  provider            = azurerm.main
  name                = local.vnet_sap_name
  resource_group_name = local.vnet_sap_resource_group_name
}

// Creates admin subnet of SAP VNET
resource "azurerm_subnet" "admin" {
  provider             = azurerm.main
  count                = !local.sub_admin_exists && local.enable_admin_subnet ? 1 : 0
  name                 = local.sub_admin_name
  resource_group_name  = local.vnet_sap_resource_group_name
  virtual_network_name = local.vnet_sap_name
  address_prefixes     = [local.sub_admin_prefix]
}

resource "azurerm_subnet_route_table_association" "admin" {
  provider       = azurerm.main
  count          = !local.sub_admin_exists && local.enable_admin_subnet && length(local.route_table_id) > 0 ? 1 : 0
  subnet_id      = local.sub_admin_exists ? data.azurerm_subnet.admin[0].id : azurerm_subnet.admin[0].id
  route_table_id = local.route_table_id
}


// Imports data of existing SAP admin subnet
data "azurerm_subnet" "admin" {
  provider             = azurerm.main
  count                = local.sub_admin_exists && local.enable_admin_subnet ? 1 : 0
  name                 = split("/", local.sub_admin_arm_id)[10]
  resource_group_name  = split("/", local.sub_admin_arm_id)[4]
  virtual_network_name = split("/", local.sub_admin_arm_id)[8]
}

// Creates db subnet of SAP VNET
resource "azurerm_subnet" "db" {
  provider             = azurerm.main
  count                = local.enable_db_deployment ? (local.sub_db_exists ? 0 : 1) : 0
  name                 = local.sub_db_name
  resource_group_name  = local.vnet_sap_resource_group_name
  virtual_network_name = local.vnet_sap_name
  address_prefixes     = [local.sub_db_prefix]
}

resource "azurerm_subnet_route_table_association" "db" {
  provider       = azurerm.main
  count          = !local.sub_db_exists && local.enable_db_deployment && length(local.route_table_id) > 0 ? 1 : 0
  subnet_id      = local.sub_db_exists ? data.azurerm_subnet.db[0].id : azurerm_subnet.db[0].id
  route_table_id = local.route_table_id
}

// Imports data of existing db subnet
data "azurerm_subnet" "db" {
  provider             = azurerm.main
  count                = local.enable_db_deployment ? (local.sub_db_exists ? 1 : 0) : 0
  name                 = split("/", local.sub_db_arm_id)[10]
  resource_group_name  = split("/", local.sub_db_arm_id)[4]
  virtual_network_name = split("/", local.sub_db_arm_id)[8]
}

// Scale out on ANF
resource "azurerm_subnet" "storage" {
  provider             = azurerm.main
  count                = local.enable_db_deployment && local.enable_storage_subnet ? (local.sub_storage_exists ? 0 : 1) : 0
  name                 = local.sub_storage_name
  resource_group_name  = local.vnet_sap_resource_group_name
  virtual_network_name = local.vnet_sap_name
  address_prefixes     = [local.sub_storage_prefix]
}

// Imports data of existing db subnet
data "azurerm_subnet" "storage" {
  provider             = azurerm.main
  count                = local.enable_db_deployment && local.enable_storage_subnet ? (local.sub_storage_exists ? 1 : 0) : 0
  name                 = split("/", local.sub_storage_arm_id)[10]
  resource_group_name  = split("/", local.sub_storage_arm_id)[4]
  virtual_network_name = split("/", local.sub_storage_arm_id)[8]
}

// Import boot diagnostics storage account from sap_landscape
data "azurerm_storage_account" "storage_bootdiag" {
  provider            = azurerm.main
  name                = local.storageaccount_name
  resource_group_name = local.storageaccount_rg_name
}

// PROXIMITY PLACEMENT GROUP
resource "azurerm_proximity_placement_group" "ppg" {
  provider            = azurerm.main
  count               = local.ppg_exists ? 0 : (local.zonal_deployment ? max(length(local.zones), 1) : 1)
  name                = format("%s%s", local.prefix, var.naming.ppg_names[count.index])
  resource_group_name = local.rg_exists ? data.azurerm_resource_group.resource_group[0].name : azurerm_resource_group.resource_group[0].name
  location            = local.rg_exists ? data.azurerm_resource_group.resource_group[0].location : azurerm_resource_group.resource_group[0].location
}

data "azurerm_proximity_placement_group" "ppg" {
  provider            = azurerm.main
  count               = local.ppg_exists ? max(length(local.zones), 1) : 0
  name                = split("/", local.ppg_arm_ids[count.index])[8]
  resource_group_name = split("/", local.ppg_arm_ids[count.index])[4]
}

# FIREWALL

resource "random_integer" "db_priority" {
  min = 2000
  max = 2999
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = local.rg_exists ? data.azurerm_resource_group.resource_group[0].name : azurerm_resource_group.resource_group[0].name
  }
}


# Create a Azure Firewall Network Rule for Azure Management API
resource "azurerm_firewall_network_rule_collection" "firewall-azure" {
  provider            = azurerm.deployer
  count               = local.firewall_exists && local.sub_db_defined && !local.sub_db_exists ? 1 : 0
  name                = format("%s%s%s", local.prefix, var.naming.separator, local.resource_suffixes.firewall_rule_db)
  azure_firewall_name = local.firewall_name
  resource_group_name = local.firewall_rgname
  priority            = random_integer.db_priority.result
  action              = "Allow"
  rule {
    name                  = "Azure-Cloud"
    source_addresses      = [local.sub_admin_prefix, local.sub_db_prefix]
    destination_ports     = ["*"]
    destination_addresses = [local.firewall_service_tags]
    protocols             = ["Any"]
  }
}

//ASG

resource "azurerm_application_security_group" "db" {
  provider = azurerm.main
  name     = format("%s%s%s", local.prefix, var.naming.separator, local.resource_suffixes.db_asg)
  resource_group_name = local.nsg_asg_with_vnet ? (
    local.vnet_sap_resource_group_name) : (
    (local.rg_exists ? (
      data.azurerm_resource_group.resource_group[0].name) : (
      azurerm_resource_group.resource_group[0].name)
    )
  )

  location = local.nsg_asg_with_vnet ? (local.vnet_sap_resource_group_location) : (local.rg_exists ? data.azurerm_resource_group.resource_group[0].location : azurerm_resource_group.resource_group[0].location)
}

