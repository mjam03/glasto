# Configure Azure provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Variables
variable "regions" {
  type = map(string)
  default = {
    "uksouth"       = "UK South"
    "ukwest"        = "UK West"
    "northeurope"   = "North Europe"
    "westeurope"    = "West Europe"
  }
}

variable "vms_per_region" {
  default = 2
}

variable "my_ip" {
  description = "Your local IP address for SSH access"
  type        = string
}

variable "pwd" {
  description = "Password for RDP access"
  type        = string
}

# Create resource groups for each region
resource "azurerm_resource_group" "rg" {
  for_each = var.regions
  name     = "vm-resources-${each.key}"
  location = each.key
}

# Virtual Networks for each region
resource "azurerm_virtual_network" "vnet" {
  for_each            = var.regions
  name                = "vm-network-${each.key}"
  address_space       = ["10.${index(keys(var.regions), each.key) + 1}.0.0/16"]
  location            = each.key
  resource_group_name = azurerm_resource_group.rg[each.key].name
}

# Subnets for each region
resource "azurerm_subnet" "subnet" {
  for_each             = var.regions
  name                 = "vm-subnet-${each.key}"
  resource_group_name  = azurerm_resource_group.rg[each.key].name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = ["10.${index(keys(var.regions), each.key) + 1}.1.0/24"]
}

# Create Network Security Groups for each region
resource "azurerm_network_security_group" "nsg" {
  for_each            = var.regions
  name                = "vm-nsg-${each.key}"
  location            = each.key
  resource_group_name = azurerm_resource_group.rg[each.key].name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "3389"
    source_address_prefix     = var.my_ip
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range     = "22"
    source_address_prefix     = var.my_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPSOutbound"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# Storage Account for Blob Storage (one per region)
resource "random_string" "random" {
  for_each = var.regions
  length   = 6
  special  = false
  upper    = false
}

resource "azurerm_storage_account" "storage" {
  for_each                 = var.regions
  name                     = "vmdata${random_string.random[each.key].result}${each.key}"
  resource_group_name      = azurerm_resource_group.rg[each.key].name
  location                 = each.key
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Container in Storage Account
resource "azurerm_storage_container" "container" {
  for_each              = var.regions
  name                  = "data"
  storage_account_name  = azurerm_storage_account.storage[each.key].name
  container_access_type = "private"
}

# Public IPs (no changes needed here)
resource "azurerm_public_ip" "pip" {
  for_each            = {
    for pair in local.vm_regions_count : "${pair.region}.${pair.idx}" => {
      region = pair.region
      index  = pair.idx
    }
  }
  name                = "vm-pip-${each.value.region}-${each.value.index + 1}"
  resource_group_name = azurerm_resource_group.rg[each.value.region].name
  location            = each.value.region
  allocation_method   = "Static"
  sku                = "Standard"
}

# Network interfaces with updated IP configuration
resource "azurerm_network_interface" "nic" {
  for_each            = {
    for pair in local.vm_regions_count : "${pair.region}.${pair.idx}" => {
      region = pair.region
      index  = pair.idx
    }
  }
  name                = "vm-nic-${each.value.region}-${each.value.index + 1}"
  location            = each.value.region
  resource_group_name = azurerm_resource_group.rg[each.value.region].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet[each.value.region].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip["${each.value.region}.${each.value.index}"].id
  }
}

# Local variables for VM and subnet calculations
locals {
  vm_regions_count = flatten([
    for region in keys(var.regions) : [
      for idx in range(var.vms_per_region) : {
        region = region
        idx    = idx
      }
    ]
  ])
}

# Connect the NSG to the network interfaces
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  for_each                  = {
    for pair in local.vm_regions_count : "${pair.region}.${pair.idx}" => {
      region = pair.region
      index  = pair.idx
    }
  }
  network_interface_id      = azurerm_network_interface.nic["${each.value.region}.${each.value.index}"].id
  network_security_group_id = azurerm_network_security_group.nsg[each.value.region].id
}

# Create virtual machines
resource "azurerm_windows_virtual_machine" "vm" {
  for_each            = {
    for pair in local.vm_regions_count : "${pair.region}.${pair.idx}" => {
      region = pair.region
      index  = pair.idx
    }
  }
  name                = "rdp-vm-${each.value.region}-${each.value.index + 1}"
  computer_name       = "vm-${substr(each.value.region, 0, 4)}${each.value.index + 1}"
  resource_group_name = azurerm_resource_group.rg[each.value.region].name
  location            = each.value.region
  size                = "Standard_D2s_v3"
  admin_username      = "azureadmin"
  admin_password      = var.pwd
  network_interface_ids = [
    azurerm_network_interface.nic["${each.value.region}.${each.value.index}"].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-21h2-pro"
    version   = "latest"
  }
}

# Install browsers using Custom Script Extension
resource "azurerm_virtual_machine_extension" "browser_install" {
  for_each             = {
    for pair in local.vm_regions_count : "${pair.region}.${pair.idx}" => {
      region = pair.region
      index  = pair.idx
    }
  }
  name                 = "browser-install"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm["${each.value.region}.${each.value.index}"].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = <<SETTINGS
  {
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Write-Host 'Installing Firefox...'; $firefoxUrl = 'https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-US'; $firefoxOutput = 'C:\\firefox.msi'; Invoke-WebRequest -Uri $firefoxUrl -OutFile $firefoxOutput; Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i C:\\firefox.msi /quiet /norestart' -Wait; Remove-Item -Path $firefoxOutput -Force; Write-Host 'Firefox installation complete'; Write-Host 'Installing Chrome...'; $chromeUrl = 'https://dl.google.com/chrome/install/latest/chrome_installer.exe'; $chromeOutput = 'C:\\chrome_installer.exe'; Invoke-WebRequest -Uri $chromeUrl -OutFile $chromeOutput; Start-Process -FilePath $chromeOutput -ArgumentList '/silent /install' -Wait; Remove-Item -Path $chromeOutput -Force; Write-Host 'Chrome installation complete'\""
  }
  SETTINGS

  timeouts {
    create = "30m"
  }
}

# Outputs
output "vm_public_ip_addresses" {
  value = {
    for key, pip in azurerm_public_ip.pip : key => pip.ip_address
  }
  description = "The public IP addresses of the VMs by region"
}

output "storage_account_names" {
  value = {
    for key, sa in azurerm_storage_account.storage : key => sa.name
  }
}

output "storage_account_keys" {
  value = {
    for key, sa in azurerm_storage_account.storage : key => sa.primary_access_key
  }
  sensitive = true
}