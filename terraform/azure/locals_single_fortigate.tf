locals {
  resource_group_name     = "fortigate-rg"
  resource_group_location = "eastus"

  prefix = "prefix-" # Change this to your own prefix, a prefix is not required but recommended to avoid name collisions

  username = "azureuser"
  password = "changeme123#@!"

  virtual_network_name = "${local.prefix}vnet"
  external_subnet_name = "snet-external"
  internal_subnet_name = "snet-internal"

  # Accelerated Networking
  # Only supported on specific VM series and CPU count: D/DSv2, D/DSv3, E/ESv3, F/FS, FSv2, and Ms/Mms
  # https://azure.microsoft.com/en-us/blog/maximize-your-vm-s-performance-with-accelerated-networking-now-generally-available-for-both-windows-and-linux/
  accelerated_networking = "true"

  external_interface_name     = "${local.prefix}fgt-ext-nic"
  external_interface_ip_octet = "4"

  internal_interface_name     = "${local.prefix}fgt-int-nic"
  internal_interface_ip_octet = "4"

  fortigate_vm_name = "${local.prefix}fgt-vm"
  fortigate_vm_size = "Standard_F8s_v2"
  fortigate_version = "7.2.5"

  fortigate_publisher                   = "fortinet"
  fortigate_image_offer_or_plan_product = "fortinet_fortigate-vm_v5"
  fortigate_image_sku_or_plan_name      = "fortinet_fg-vm" # BYOL: fortinet_fg-vm or PAYG: fortinet_fg-vm_payg_2023

  # Either one of these can be used to license to the BYOL FortiGate
  fortigate_byol_license_file   = "" # Change this to your own license filename, can be uploaded after deployment
  fortigate_byol_license_token  = "" # Change this to your own license token if using FortiFlex licensing, can be set after deployment
  
  fortigate_ssh_public_key_file = "" # Change this to your own SSH public key filename, can be set after deployment

  tags = {
    publisher = "Fortinet"
  }

  # To use a public IP address for the FortiGate, set to true
  public_ip_enabled = true
  public_ip_name    = "${local.prefix}fgt-pip"
  public_ips = {
    (local.public_ip_name) = {
      name              = (local.public_ip_name)
      allocation_method = "Static"
      sku               = "Standard"
    }
  }
}