// Input arguments 
variable naming {
  description = "Defines the names for the resources"
}

// Imports from tfstate
locals {

  resource_suffixes    = var.naming.resource_suffixes
  // Get deployer remote tfstate info
  deployer_config = try(var.infrastructure.vnets.management, {})

  // Default value follows naming convention
  saplib_resource_group_name   = try(local.deployer_config.saplib_resource_group_name, format("%s%s", var.naming.prefix.LIBRARY, local.resource_suffixes.library-rg))
  tfstate_storage_account_name = try(local.deployer_config.tfstate_storage_account_name, "")
  tfstate_container_name       = "tfstate"
  deployer_tfstate_key         = try(local.deployer_config.deployer_tfstate_key, format("%s%s", var.naming.prefix.DEPLOYER, local.resource_suffixes.deployer-state))
}
