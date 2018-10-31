output "fqdn" {
  description = "The fully qualified domain name associated with the public IP that was created."
  value       = "${azurerm_public_ip.pip.fqdn}"
}

output "nic_id" {
  description = "The id of the network interface card will be needed to attach it to the VM."
  value       = "${azurerm_network_interface.nic.id}"
}

output "nic_name" {
  description = "The name of the network interface"
  value       = "${azurerm_network_interface.nic.name}"
}
