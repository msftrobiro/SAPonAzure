# Configure the Microsoft Azure Provider
provider "azurerm" {}

data "http" "local_ip" {
  url = "http://ifconfig.co"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myterraformgroup" {
  name     = "pabowersResourceGroup"
  location = "eastus"

  tags {
    environment = "Terraform SAP deployment"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "pv1-vnet" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/21"]
  location            = "eastus"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

  tags {
    environment = "Terraform SAP deployment"
  }
}

# Create subnet
resource "azurerm_subnet" "pv1-subnet" {
  name                      = "mySubnet"
  resource_group_name       = "${azurerm_resource_group.myterraformgroup.name}"
  virtual_network_name      = "${azurerm_virtual_network.pv1-vnet.name}"
  network_security_group_id = "${azurerm_network_security_group.pv1-nsg.id}"
  address_prefix            = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
  name                         = "myPublicIP"
  location                     = "eastus"
  resource_group_name          = "${azurerm_resource_group.myterraformgroup.name}"
  public_ip_address_allocation = "dynamic"
  idle_timeout_in_minutes      = 30
  domain_name_label            = "hana-terraform-dn"

  tags {
    environment = "Terraform SAP deployment"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "pv1-nsg" {
  name                = "myNetworkSecurityGroup"
  location            = "eastus"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # TODO(pabowers): disable access after ssh connecting, mounting, and installing
  security_rule {
    name                       = "local-ip-allow-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "${chomp(data.http.local_ip.body)}"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "open-hana-db-ports"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-30099"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1040
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4300"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "Terraform SAP deployment"
  }
}

locals {
  user_name      = "azureuser"
  vmFqdn         = "${azurerm_public_ip.myterraformpublicip.fqdn}"
  hanaDataSize   = 512
  hanaLogSize    = 512
  hanaSharedSize = 512
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
  name                      = "myNIC"
  location                  = "eastus"
  resource_group_name       = "${azurerm_resource_group.myterraformgroup.name}"
  network_security_group_id = "${azurerm_network_security_group.pv1-nsg.id}"

  ip_configuration {
    name      = "myNicConfiguration"
    subnet_id = "${azurerm_subnet.pv1-subnet.id}"

    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
  }

  tags {
    environment = "Terraform SAP deployment"
  }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.myterraformgroup.name}"
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.myterraformgroup.name}"
  location                 = "eastus"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags {
    environment = "Terraform SAP deployment"
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "db0" {
  name                  = "db0"
  location              = "eastus"
  resource_group_name   = "${azurerm_resource_group.myterraformgroup.name}"
  network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
  vm_size               = "Standard_E8s_v3"

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "SUSE"
    offer     = "SLES-SAP"
    sku       = "12-SP3"
    version   = "latest"
  }

  storage_data_disk {
    name              = "hana-data-disk"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    disk_size_gb      = "${local.hanaDataSize}"
    lun               = 0
  }

  storage_data_disk {
    name              = "hana-log-disk"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    disk_size_gb      = "${local.hanaLogSize}"
    lun               = 1
  }

  storage_data_disk {
    name              = "hana-shared-disk"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    disk_size_gb      = "${local.hanaSharedSize}"
    lun               = 2
  }

  os_profile {
    computer_name  = "myvm"
    admin_username = "${local.user_name}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/id_rsa.pub")}"
    }
  }

  boot_diagnostics {
    enabled = "true"

    storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
  }

  connection {
    user        = "${local.user_name}"
    private_key = "${file("~/.ssh/id_rsa")}"
    timeout     = "20m"
    host        = "${local.vmFqdn}"
  }

  provisioner "file" {
    source      = "hanaSetup.sh"
    destination = "/tmp/hanaSetup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/hanaSetup.sh",
      "sudo /tmp/hanaSetup.sh",
    ]
  }

  tags {
    environment = "Terraform SAP deployment"
  }
}

// -------------------------------------------------------------------------
// Print out login information
// -------------------------------------------------------------------------
output "ip" {
  value = "Created vm ${azurerm_virtual_machine.db0.id}"
  value = "Connect using ${local.user_name}@${local.vmFqdn}"
}
