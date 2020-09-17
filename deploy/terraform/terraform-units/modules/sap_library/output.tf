output "tfstate_storage_account" {
  value = local.sa_tfstate
}

output "sapbits_storage_account" {
  value = local.sa_sapbits
}

output "storagecontainer_tfstate" {
  value = local.storagecontainer_tfstate
}

output "storagecontainer_sapbits" {
  value = local.storagecontainer_sapbits
}

output "fileshare_sapbits_name" {
  value = local.fileshare_sapbits_name
}

output "user_vault_name" {
  value = azurerm_key_vault.kv_user.name
}

output "downloader_username_secret_name" {
  value = azurerm_key_vault_secret.downloader_username.name
}

output "downloader_password_secret_name" {
  value = azurerm_key_vault_secret.downloader_password.name
}
