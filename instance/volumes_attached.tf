locals {
    named_volumes = distinct(flatten([ for machine in var.machines: [
            for volume in machine.attach_volumes: volume
        ] if machine.attach_volumes != null
    ]))
    # flatten([var.machines[*].flavor_name])/// : []
}

data "openstack_blockstorage_volume_v3" "existing_volumes" {
    for_each = { for name in local.named_volumes: name => name }
    name = each.value
}

locals {
    machines_and_volumes = flatten([
        for machine_name, machine in var.machines: [
            for volume_name in machine.attach_volumes: {
                machine_id = machine_name
                volume_id = volume_name
            }
        ] if machine.attach_volumes != null
    ])
}

resource "openstack_compute_volume_attach_v2" "va_1" {
    for_each = { for att in local.machines_and_volumes: "${att.machine_id}-${att.volume_id}" => att }

    instance_id = openstack_compute_instance_v2.instances[each.value.machine_id].id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[each.value.volume_id].id
}