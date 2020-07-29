/*
Description:

  Output from sap_deployer module.
*/

// Unique ID for deployer
output "deployer-id" {
  value = random_id.deployer
}

// Details of management vnet that is deployed/imported
output "vnet-mgmt" {
  value = local.vnet_mgmt_exists ? data.azurerm_virtual_network.vnet-mgmt[0] : azurerm_virtual_network.vnet-mgmt[0]
}

// Details of management subnet that is deployed/imported
output "subnet-mgmt" {
  value = local.sub_mgmt_exists ? data.azurerm_subnet.subnet-mgmt[0] : azurerm_subnet.subnet-mgmt[0]
}

// Details of the management vnet NSG that is deployed/imported
output "nsg-mgmt" {
  value = local.sub_mgmt_nsg_exists ? data.azurerm_network_security_group.nsg-mgmt[0] : azurerm_network_security_group.nsg-mgmt[0]
}

// Details of the user assigned identity for deployer(s)
output "deployer-uai" {
  value = azurerm_user_assigned_identity.deployer
}

// Details of deployer pip(s)
output "deployer-pip" {
  value = azurerm_public_ip.deployer
}

// Details of deployer(s)
output "deployers" {
  value = local.deployers_updated
}

