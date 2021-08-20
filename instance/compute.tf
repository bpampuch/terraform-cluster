locals {
    machines_with_flavors = {for key, value in var.machines : key => value if value.flavor_name != null}
    machines_with_generate_fip = {for key, value in var.machines : key => value if try(value.generate_fip, false)}
    defined_fips = {for key, value in local.machines_with_flavors : key => value.floating_ip if value.floating_ip != null}
}

resource "openstack_compute_instance_v2" "instances" {
    for_each        = local.machines_with_flavors

    name            = "${var.environment}-${each.key}"
    flavor_name     = each.value.flavor_name
    key_pair        = var.key_pair

    security_groups = each.value.security_groups

    block_device {
        uuid                = openstack_blockstorage_volume_v3.volumes[each.key].id
        source_type           = "volume"
        boot_index            = 0
        destination_type      = "volume"
        volume_size           = 0           // to prevent 0 -> null 
        #delete_on_termination = false
    }

    network {
        name = each.value.network_name
        fixed_ip_v4 = each.value.fixed_ip
    }

    availability_zone = each.value.availability_zone

    user_data = file("${path.module}/sshdnsoff.sh")

    lifecycle {
        ignore_changes = [
            scheduler_hints,
            tags
        ]
    }

    scheduler_hints {
        group = each.value.server_group
    }
}


resource "openstack_compute_floatingip_associate_v2" "fips" {
    for_each        = local.defined_fips

    floating_ip     = each.value
    instance_id     = openstack_compute_instance_v2.instances[each.key].id
}


resource "openstack_networking_floatingip_v2" "generate_fips" {
    for_each        = local.machines_with_generate_fip
    pool            = var.external_network_name
}


resource "openstack_compute_floatingip_associate_v2" "generate_fip_pins" {
    for_each        = local.machines_with_generate_fip
    
    floating_ip     = openstack_networking_floatingip_v2.generate_fips[each.key].address
    instance_id     = openstack_compute_instance_v2.instances[each.key].id
}
