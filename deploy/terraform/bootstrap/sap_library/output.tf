output "tfstate_storage_account" {
  sensitive = true
  value     = local.sa_tfstate
}

output "sapbits_storage_account" {
  sensitive = true
  value     = local.sa_sapbits
}

output "storagecontainer_saplibrary" {
  sensitive = true
  value     = local.storagecontainer_saplibrary
}

output "storagecontainer_sapbits" {
  sensitive = true
  value     = local.storagecontainer_sapbits
}

output "fileshare_sapbits_name" {
  sensitive = true
  value     = local.fileshare_sapbits_name
}
