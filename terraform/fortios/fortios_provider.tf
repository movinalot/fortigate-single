terraform {
  required_providers {
    fortios = {
      source  = "fortinetdev/fortios"
      version = "~>1.16.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "fortios" {
  hostname = local.fortigate_ip_or_fqdn
  token    = local.fortigate_api_token
  insecure = "true"
}
