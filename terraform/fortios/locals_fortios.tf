locals {

  fortigate_ip_or_fqdn = ""
  fortigate_api_token  = ""

  sdn_connectors = {
    "AzureSDN" = {
      name = "AzureSDN"

      azure_region     = "global"
      status           = "enable"
      type             = "azure"
      update_interval  = 60
      use_metadata_iam = "enable"
      subscription_id  = ""
      resource_group   = ""
    }
  }

  firewall_addresses = {
    # Uncomment the following block to create a firewall address
    #"WebServers" = {
    #  name                 = "WebServers"
    #  associated_interface = "port2"
    #  type                 = "dynamic"
    #  sdn                  = fortios_system_sdnconnector.system_sdnconnector["AzureSDN"].name
    #  filter               = "Tag.ComputeType=WebServer"
    #}
  }

  firewall_policys = {
    "AllowAll_In" = {
      name = "AllowAll_In"

      action     = "accept"
      logtraffic = "all"
      nat        = "enable"
      status     = "enable"
      schedule   = "always"

      srcintf = [
        {
          name = "port1"
        }
      ]

      dstintf = [
        {
          name = "port2"
        }
      ]

      srcaddr = [
        {
          name = "all"
        }
      ]

      dstaddr = [
        {
          name = "all"
        }
      ]

      service = [
        {
          name = "ALL"
        }
      ]
    }
    "AllowAll_Out" = {
      name = "AllowAll_Out"

      action     = "accept"
      logtraffic = "all"
      nat        = "disable"
      status     = "enable"
      schedule   = "always"

      srcintf = [
        {
          name = "port2"
        }
      ]

      dstintf = [
        {
          name = "port1"
        }
      ]

      srcaddr = [
        {
          name = "all"
        }
      ]

      dstaddr = [
        {
          name = "all"
        }
      ]

      service = [
        {
          name = "ALL"
        }
      ]
    }
  }
}