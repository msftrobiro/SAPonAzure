# Configure the Microsoft Azure Provider
provider "azurerm" {}

variable "region" {}

variable "userName" {
  description = "The username of your HANA db vm."
}

variable "resource-group-name" {
  default = "hana-db-pv-rg"
}

variable "SID" {
  default = "pv1"
}

variable "instance-no" {
  description = "the sap instance number which is in range 00-99"
}

data "http" "local_ip" {
  url = "http://ifconfig.co"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "hana-resource-group" {
  name     = "${var.resource-group-name}"
  location = "${var.region}"

  tags {
    environment = "Terraform SAP HANA single node deployment"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "hana-vnet" {
  name                = "${var.SID}-vnet"
  address_space       = ["10.0.0.0/21"]
  location            = "${var.region}"
  resource_group_name = "${azurerm_resource_group.hana-resource-group.name}"

  tags {
    environment = "Terraform SAP HANA single node deployment"
  }
}

# Create subnet
resource "azurerm_subnet" "hana-subnet" {
  name                      = "${var.SID}-subnet"
  resource_group_name       = "${azurerm_resource_group.hana-resource-group.name}"
  virtual_network_name      = "${azurerm_virtual_network.hana-vnet.name}"
  network_security_group_id = "${azurerm_network_security_group.pv1-nsg.id}"
  address_prefix            = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "hana-db-pip" {
  name                         = "${var.SID}-db0-pip"
  location                     = "${var.region}"
  resource_group_name          = "${azurerm_resource_group.hana-resource-group.name}"
  public_ip_address_allocation = "dynamic"
  idle_timeout_in_minutes      = 30
  domain_name_label            = "hana-dn"

  tags {
    environment = "Terraform SAP HANA single node deployment"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "pv1-nsg" {
  name                = "pv1-nsg"
  location            = "${var.region}"
  resource_group_name = "${azurerm_resource_group.hana-resource-group.name}"

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
    destination_port_range     = "3${var.instance-no}00-3${var.instance-no}99"
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
    destination_port_range     = "80${var.instance-no}"
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
    destination_port_range     = "43${var.instance-no}"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "Terraform SAP HANA single node deployment"
  }
}

locals {
  vmFqdn         = "${azurerm_public_ip.hana-db-pip.fqdn}"
  hanaDataSize   = 512
  hanaLogSize    = 512
  hanaSharedSize = 512
}

# Create network interface
resource "azurerm_network_interface" "pv1-db0-nic" {
  name                      = "pv1-db0-nic"
  location                  = "${var.region}"
  resource_group_name       = "${azurerm_resource_group.hana-resource-group.name}"
  network_security_group_id = "${azurerm_network_security_group.pv1-nsg.id}"

  ip_configuration {
    name      = "myNicConfiguration"
    subnet_id = "${azurerm_subnet.hana-subnet.id}"

    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.hana-db-pip.id}"
  }

  tags {
    environment = "Terraform SAP HANA single node deployment"
  }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.hana-resource-group.name}"
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.hana-resource-group.name}"
  location                 = "${var.region}"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags {
    environment = "Terraform SAP HANA single node deployment"
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "db0" {
  name                  = "db0"
  location              = "${var.region}"
  resource_group_name   = "${azurerm_resource_group.hana-resource-group.name}"
  network_interface_ids = ["${azurerm_network_interface.pv1-db0-nic.id}"]
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
    computer_name  = "pv1-db0"
    admin_username = "${var.userName}"
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
    user        = "${var.userName}"
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
    environment = "Terraform SAP HANA single node deployment"
  }
}

// -------------------------------------------------------------------------
// Print out login information
// -------------------------------------------------------------------------
output "ip" {
  value = "Created vm ${azurerm_virtual_machine.db0.id}"
  value = "Connect using ${var.userName}@${local.vmFqdn}"
}
