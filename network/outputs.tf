output "network_names" {
    value = { for key, net in openstack_networking_network_v2.net: key => net.name }
}

output "networks" {
    value = { for key, net in openstack_networking_network_v2.net: key => net }
}

output "cidrs" {
    value = local.cidr_by_names
}

output "security_group_names" {
    value = { for name, group in openstack_networking_secgroup_v2.security_groups: name => group.name }
}