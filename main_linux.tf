# # Configure Azure provider
# provider "azurerm" {
#   features {}
# }

# # Variables
# variable "resource_group_location" {
#   default = "uksouth"
# }

# variable "my_ip" {
#   description = "Your local IP address for SSH access"
#   type        = string
# }

# # Create resource group
# resource "azurerm_resource_group" "rg" {
#   name     = "vm-resources"
#   location = var.resource_group_location
# }

# # Virtual Network
# resource "azurerm_virtual_network" "vnet" {
#   name                = "vm-network"
#   address_space       = ["10.0.0.0/16"]
#   location           = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
# }

# # Subnet
# resource "azurerm_subnet" "subnet" {
#   name                 = "vm-subnet"
#   resource_group_name  = azurerm_resource_group.rg.name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   address_prefixes     = ["10.0.1.0/24"]
# }

# # Create Network Security Group
# resource "azurerm_network_security_group" "nsg" {
#   name                = "vm-nsg"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name

#   security_rule {
#     name                       = "RDP"
#     priority                   = 1000
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range         = "*"
#     destination_port_range    = "3389"
#     source_address_prefix     = var.my_ip
#     destination_address_prefix = "*"
#   }

#   # XRDP access
#   security_rule {
#     name                       = "XRDP"
#     priority                   = 1001
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range         = "*"
#     destination_port_range    = "3389"
#     source_address_prefix     = var.my_ip
#     destination_address_prefix = "*"
#   }
  
#   security_rule {
#     name                       = "SSH"
#     priority                   = 1002
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range         = "*"
#     destination_port_range     = "22"
#     source_address_prefix     = var.my_ip
#     destination_address_prefix = "*"
#   }

#   security_rule {
#     name                       = "AllowHTTPSOutbound"
#     priority                   = 1003
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range         = "*"
#     destination_port_range     = "443"
#     source_address_prefix      = "*"
#     destination_address_prefix = "Internet"
#   }
# }

# # Create network interfaces
# resource "azurerm_network_interface" "nic" {
#   count               = 2
#   name                = "vm-nic-${count.index + 1}"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name

#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.subnet.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.pip[count.index].id
#   }
# }

# # Connect the NSG to the network interfaces
# resource "azurerm_network_interface_security_group_association" "nsg_association" {
#   count                     = 2
#   network_interface_id      = azurerm_network_interface.nic[count.index].id
#   network_security_group_id = azurerm_network_security_group.nsg.id
# }

# # Storage Account for Blob Storage
# resource "azurerm_storage_account" "storage" {
#   name                     = "vmdata${random_string.random.result}"
#   resource_group_name      = azurerm_resource_group.rg.name
#   location                = azurerm_resource_group.rg.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
# }

# resource "random_string" "random" {
#   length  = 8
#   special = false
#   upper   = false
# }

# # Container in Storage Account
# resource "azurerm_storage_container" "container" {
#   name                  = "data"
#   storage_account_name  = azurerm_storage_account.storage.name
#   container_access_type = "private"
# }

# # VM Creation (repeated for 2 VMs)
# resource "azurerm_public_ip" "pip" {
#   count               = 2
#   name                = "vm-pip-${count.index + 1}"
#   resource_group_name = azurerm_resource_group.rg.name
#   location           = azurerm_resource_group.rg.location
#   allocation_method   = "Static"
#   sku                = "Standard"
# }

# # Generate SSH key pair
# resource "tls_private_key" "ssh" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# # Create Linux virtual machines
# resource "azurerm_linux_virtual_machine" "vm" {
#   count               = 2
#   name                = "rdp-vm-${count.index + 1}"
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   size                = "Standard_D2s_v3"  # Good for GUI performance
#   admin_username      = "azureuser"
  
#   network_interface_ids = [
#     azurerm_network_interface.nic[count.index].id
#   ]

#   admin_ssh_key {
#     username   = "azureuser"
#     public_key = tls_private_key.ssh.public_key_openssh
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Premium_LRS"  # Premium SSD for better performance
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }

#   custom_data = base64encode(<<-EOF
#               #!/bin/bash
#               apt-get update
#               apt-get install -y ubuntu-desktop firefox xrdp
#               systemctl enable xrdp
#               systemctl start xrdp
#               EOF
#   )
# }

# # Output the public IPs and SSH private key
# output "vm_public_ips" {
#   value = azurerm_public_ip.pip[*].ip_address
#   description = "The public IP addresses of the VMs"
# }

# output "ssh_private_key" {
#   value     = tls_private_key.ssh.private_key_pem
#   sensitive = true
# }

# output "storage_account_name" {
#   value = azurerm_storage_account.storage.name
# }

# output "storage_account_key" {
#   value     = azurerm_storage_account.storage.primary_access_key
#   sensitive = true
# }
