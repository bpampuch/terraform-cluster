data "openstack_images_image_v2" "images" {
    for_each        = var.machines
    name            = each.value.image_name
}

locals {
    image_ids = {for i in data.openstack_images_image_v2.images : i.name => i.id...}
}

resource "openstack_blockstorage_volume_v3" "volumes" {
    for_each        = var.machines
    name            = "${var.environment}-${each.key}"
    size            = each.value.volume_size
    image_id        = local.image_ids[each.value.image_name].0
    enable_online_resize = true
    availability_zone = each.value.availability_zone
    volume_type     = each.value.volume_type
}

module "attached_volumes" {
    source = "../ordered_volume_attach"

    for_each        = local.machines_with_flavors
    instance_id     = openstack_compute_instance_v2.instances[each.key].id
    volume_names    = each.value.attach_volumes
}