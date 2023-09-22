# FortiGate Standalone VM
# Terraform deployment for Microsoft Azure

# Retrieve existing Resource Group information
data "azurerm_resource_group" "resource_group" {
  name = local.resource_group_name
}

# Retrieve existing Virtual Network information
data "azurerm_virtual_network" "virtual_network" {
  resource_group_name = data.azurerm_resource_group.resource_group.name
  name                = local.virtual_network_name
}

# Retrieve existing Subnet information
data "azurerm_subnet" "external" {
  resource_group_name  = data.azurerm_resource_group.resource_group.name
  virtual_network_name = data.azurerm_virtual_network.virtual_network.name
  name                 = local.external_subnet_name
}

data "azurerm_subnet" "internal" {
  resource_group_name  = data.azurerm_resource_group.resource_group.name
  virtual_network_name = data.azurerm_virtual_network.virtual_network.name
  name                 = local.internal_subnet_name
}

# Generate random string for API key
resource "random_string" "string" {
  length  = 30
  special = false
}

# Create Public IP address if enabled in locals
resource "azurerm_public_ip" "public_ip" {
  for_each = local.public_ip_enabled ? local.public_ips : {}

  resource_group_name = data.azurerm_resource_group.resource_group.name
  location            = data.azurerm_resource_group.resource_group.location
  name                = each.value.name
  allocation_method   = each.value.allocation_method
  sku                 = each.value.sku
}

# Create Network Interfaces
resource "azurerm_network_interface" "network_interface_ext" {
  resource_group_name           = data.azurerm_resource_group.resource_group.name
  location                      = data.azurerm_resource_group.resource_group.location
  name                          = local.external_interface_name
  enable_ip_forwarding          = true
  enable_accelerated_networking = local.accelerated_networking

  ip_configuration {
    name                          = "ipconfig1"
    primary                       = true
    subnet_id                     = data.azurerm_subnet.external.id
    private_ip_address_allocation = "Static"
    # The FGT_EXT_IPADDR_OCTET variable is used to set the last octet of the external IP address, set it to a free IP address in the external subnet
    private_ip_address = cidrhost(data.azurerm_subnet.external.address_prefixes[0], local.external_interface_ip_octet)
    # Public IP address is optional and only assigned if enabled in locals
    public_ip_address_id = local.public_ip_enabled ? azurerm_public_ip.public_ip[local.public_ip_name].id : null
  }
}

resource "azurerm_network_interface" "network_interface_int" {
  resource_group_name           = data.azurerm_resource_group.resource_group.name
  location                      = data.azurerm_resource_group.resource_group.location
  name                          = local.internal_interface_name
  enable_ip_forwarding          = true
  enable_accelerated_networking = local.accelerated_networking

  ip_configuration {
    name                          = "ipconfig1"
    primary                       = true
    subnet_id                     = data.azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    # The FGT_INT_IPADDR_OCTET variable is used to set the last octet of the internal IP address, set it to a free IP address in the internal subnet
    private_ip_address = cidrhost(data.azurerm_subnet.internal.address_prefixes[0], local.internal_interface_ip_octet)
  }
}

resource "azurerm_linux_virtual_machine" "linux_virtual_machine_fgtvm" {
  resource_group_name = data.azurerm_resource_group.resource_group.name
  location            = data.azurerm_resource_group.resource_group.location

  name                  = local.fortigate_vm_name
  network_interface_ids = [azurerm_network_interface.network_interface_ext.id, azurerm_network_interface.network_interface_int.id]
  size                  = local.fortigate_vm_size

  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    publisher = local.fortigate_publisher
    offer     = local.fortigate_image_offer_or_plan_product
    sku       = local.fortigate_image_sku_or_plan_name
    version   = local.fortigate_version
  }

  plan {
    publisher = local.fortigate_publisher
    product   = local.fortigate_image_offer_or_plan_product
    name      = local.fortigate_image_sku_or_plan_name
  }

  os_disk {
    name                 = "${local.fortigate_vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_username = local.username
  admin_password = local.password

  disable_password_authentication = false


  custom_data = base64encode(templatefile("${path.module}/templates/fortios_config.tpl", {
    fgt_vm_name           = local.fortigate_vm_name
    fgt_license_file      = local.fortigate_byol_license_file
    fgt_license_fortiflex = local.fortigate_byol_license_token
    fgt_username          = local.username
    fgt_ssh_public_key    = local.fortigate_ssh_public_key_file
    api_key               = random_string.string.id
    fgt_external_ipaddr   = cidrhost(data.azurerm_subnet.external.address_prefixes[0], local.external_interface_ip_octet)
    fgt_external_mask     = cidrnetmask(data.azurerm_subnet.external.address_prefixes[0])
    fgt_external_gw       = cidrhost(data.azurerm_subnet.external.address_prefixes[0], 1)
    fgt_internal_ipaddr   = cidrhost(data.azurerm_subnet.internal.address_prefixes[0], local.internal_interface_ip_octet)
    fgt_internal_mask     = cidrnetmask(data.azurerm_subnet.internal.address_prefixes[0])
    fgt_internal_gw       = cidrhost(data.azurerm_subnet.internal.address_prefixes[0], 1)
    vnet_network          = data.azurerm_virtual_network.virtual_network.address_space[0]
  }))

  boot_diagnostics {
  }

  tags = local.tags
}

resource "azurerm_managed_disk" "managed_disk" {
  resource_group_name  = data.azurerm_resource_group.resource_group.name
  location             = data.azurerm_resource_group.resource_group.location
  name                 = "${local.fortigate_vm_name}-disk"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 50
}

resource "azurerm_virtual_machine_data_disk_attachment" "virtual_machine_data_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.managed_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.linux_virtual_machine_fgtvm.id
  lun                = 0
  caching            = "ReadWrite"
}

resource "local_sensitive_file" "tempalte_file" {

  filename = "fortios_config.cfg"
  content = templatefile("${path.module}/templates/fortios_config.tpl", {
    fgt_vm_name           = local.fortigate_vm_name
    fgt_license_file      = local.fortigate_byol_license_file
    fgt_license_fortiflex = local.fortigate_byol_license_token
    fgt_username          = local.username
    fgt_ssh_public_key    = local.fortigate_ssh_public_key_file
    api_key               = random_string.string.id
    fgt_external_ipaddr   = cidrhost(data.azurerm_subnet.external.address_prefixes[0], local.external_interface_ip_octet)
    fgt_external_mask     = cidrnetmask(data.azurerm_subnet.external.address_prefixes[0])
    fgt_external_gw       = cidrhost(data.azurerm_subnet.external.address_prefixes[0], 1)
    fgt_internal_ipaddr   = cidrhost(data.azurerm_subnet.internal.address_prefixes[0], local.internal_interface_ip_octet)
    fgt_internal_mask     = cidrnetmask(data.azurerm_subnet.internal.address_prefixes[0])
    fgt_internal_gw       = cidrhost(data.azurerm_subnet.internal.address_prefixes[0], 1)
    vnet_network          = data.azurerm_virtual_network.virtual_network.address_space[0]
  })
}

output "deployment_summary" {
  value = templatefile("${path.module}/templates/output.tpl", {
    resource_group_name        = data.azurerm_resource_group.resource_group.name
    location                   = data.azurerm_resource_group.resource_group.location
    username                   = local.username
    fgt_private_ip_address_ext = azurerm_network_interface.network_interface_ext.private_ip_address
    fgt_private_ip_address_int = azurerm_network_interface.network_interface_int.private_ip_address
    fgt_api_key                = random_string.string.id
    fgt_public_ip_address      = local.public_ip_enabled ? format("https://%s", azurerm_public_ip.public_ip[local.public_ip_name].ip_address) : "None"
  })
}