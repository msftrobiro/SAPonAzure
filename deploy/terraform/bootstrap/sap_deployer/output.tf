/*
Description:

  Output from sap_deployer module.
*/

output "deployer-id" {
  value = module.sap_deployer.deployer-id
}

output "vnet-mgmt" {
  value = module.sap_deployer.vnet-mgmt
}

output "subnet-mgmt" {
  value = module.sap_deployer.subnet-mgmt
}

output "nsg-mgmt" {
  value = module.sap_deployer.nsg-mgmt
}

output "deployer-uai" {
  value = module.sap_deployer.deployer-uai
}

output "deployer" {
  value = module.sap_deployer.deployers
}
