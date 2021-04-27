locals {
    # https://www.terraform.io/docs/language/functions/flatten.html
    tcp_rules = flatten([
        for network_key, network_rules in var.network_rules: [
            for remoteip, ports in network_rules.in_tcp: [
                for port in ports: {
                    network_key = network_key
                    remote_ip_prefix = try(local.cidr_by_names[remoteip], remoteip)
                    # https://stackoverflow.com/questions/47243474/how-to-check-if-string-contains-a-substring-in-terraform-interpolation
                    port_min = replace(tostring(port), "-", "") != tostring(port) ? split("-", tostring(port))[0] : port
                    port_max = replace(tostring(port), "-", "") != tostring(port) ? split("-", tostring(port))[1] : port
                }
            ] if network_rules.in_tcp != null
        ]
    ])

    udp_rules = flatten([
        for network_key, network_rules in var.network_rules: [
            for remoteip, ports in network_rules.in_udp: [
                for port in ports: {
                    network_key = network_key
                    remote_ip_prefix = try(local.cidr_by_names[remoteip], remoteip)
                    # https://stackoverflow.com/questions/47243474/how-to-check-if-string-contains-a-substring-in-terraform-interpolation
                    port_min = replace(tostring(port), "-", "") != tostring(port) ? split("-", tostring(port))[0] : port
                    port_max = replace(tostring(port), "-", "") != tostring(port) ? split("-", tostring(port))[1] : port
                }
            ]
        ] if network_rules.in_udp != null
    ])
}

resource "openstack_networking_secgroup_v2" "security_groups" {
    for_each             = var.network_rules

    name                 = "${var.environment}-${each.key}-rules"
    description          = "${var.environment} - rules for ${each.key} network"
    delete_default_rules = "true"
}

resource "openstack_networking_secgroup_rule_v2" "in_tcp_rules" {
    for_each        = { for rule in local.tcp_rules: "${rule.network_key}-${rule.remote_ip_prefix}-${rule.port_min}-${rule.port_max}" => rule }

    direction         = "ingress"
    ethertype         = "IPv4"
    protocol          = "tcp"
    port_range_min    = each.value.port_min
    port_range_max    = each.value.port_max
    remote_ip_prefix  = each.value.remote_ip_prefix
    security_group_id = openstack_networking_secgroup_v2.security_groups[each.value.network_key].id
}


resource "openstack_networking_secgroup_rule_v2" "in_udp_rules" {
    for_each        = { for rule in local.udp_rules: "${rule.network_key}-${rule.remote_ip_prefix}-${rule.port_min}-${rule.port_max}" => rule }

    direction         = "ingress"
    ethertype         = "IPv4"
    protocol          = "udp"
    port_range_min    = each.value.port_min
    port_range_max    = each.value.port_max
    remote_ip_prefix  = each.value.remote_ip_prefix
    security_group_id = openstack_networking_secgroup_v2.security_groups[each.value.network_key].id
}


// by default we allow all out
resource "openstack_networking_secgroup_rule_v2" "allow_all_out_tcp" {
    for_each        = openstack_networking_secgroup_v2.security_groups

    direction         = "egress"
    ethertype         = "IPv4"
    protocol          = "tcp"
    remote_ip_prefix  = "0.0.0.0/0"
    security_group_id = each.value.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_all_out_udp" {
    for_each        = openstack_networking_secgroup_v2.security_groups

    direction         = "egress"
    ethertype         = "IPv4"
    protocol          = "udp"
    remote_ip_prefix  = "0.0.0.0/0"
    security_group_id = each.value.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_all_out_icmp" {
    for_each        = openstack_networking_secgroup_v2.security_groups

    direction         = "egress"
    ethertype         = "IPv4"
    protocol          = "icmp"
    remote_ip_prefix  = "0.0.0.0/0"
    security_group_id = each.value.id
}
