data "openstack_networking_network_v2" "external_network" {
    name = var.external_network_name
}

resource "openstack_networking_network_v2" "net" {
    for_each       = var.networks

    name           = "${var.environment}-${each.key}"
    admin_state_up = "true"
}

locals {
    cidr_by_names = var.networks
}

resource "openstack_networking_subnet_v2" "subnets" {
    for_each       = openstack_networking_network_v2.net

    network_id     = each.value.id
    cidr           = local.cidr_by_names[trimprefix(each.value.name, "${var.environment}-")]
    ip_version     = 4
    dns_nameservers = var.dns_servers
}

resource "openstack_networking_router_v2" "router" {
    name =  "${var.environment}-router"
    external_network_id = data.openstack_networking_network_v2.external_network.id
    depends_on = [openstack_networking_subnet_v2.subnets]
}

######################################################################################################
resource "openstack_networking_router_interface_v2" "router-interfaces" {
    for_each       = openstack_networking_subnet_v2.subnets

    router_id     = openstack_networking_router_v2.router.id
    subnet_id     = each.value.id
    depends_on =  [openstack_networking_router_v2.router, openstack_networking_subnet_v2.subnets]
}
