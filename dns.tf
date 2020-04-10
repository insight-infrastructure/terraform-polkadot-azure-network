locals {
  public_domain = join(".", [data.azurerm_resource_group.this.location, var.environment, "azure", var.network_name, var.root_domain_name])
}

data cloudflare_zones "this" {
  filter {
    name = var.root_domain_name
  }
}

resource "cloudflare_record" "public_delegation" {
  count   = var.root_domain_name == "" ? 0 : 4
  name    = "azure.${var.network_name}.${var.root_domain_name}"
  value   = flatten(azurerm_dns_zone.this[0].name_servers)[count.index]
  type    = "NS"
  zone_id = data.cloudflare_zones.this.zones[0].id
}

resource "azurerm_dns_zone" "this" {
  count               = var.root_domain_name == "" ? 0 : 1
  name                = "azure.${var.network_name}.${var.root_domain_name}"
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone" "root_private" {
  count               = var.create_internal_domain ? 1 : 0
  name                = "${var.namespace}.${var.internal_tld}"
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_dns_zone" "region_public" {
  count               = var.create_public_regional_subdomain ? 1 : 0
  name                = local.public_domain
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_dns_ns_record" "region_public" {
  count               = var.create_public_regional_subdomain ? 1 : 0
  name                = local.public_domain
  resource_group_name = data.azurerm_resource_group.this.name
  ttl                 = 30
  zone_name           = azurerm_dns_zone.this[0].name
  records = [
    flatten(azurerm_dns_zone.region_public.*.name_servers)[0],
    flatten(azurerm_dns_zone.region_public.*.name_servers)[1],
    flatten(azurerm_dns_zone.region_public.*.name_servers)[2],
    flatten(azurerm_dns_zone.region_public.*.name_servers)[3],
  ]
}