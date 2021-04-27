data "openstack_images_image_v2" "images" {
    for_each        = var.machines
    name            = each.value.image_name
}

locals {
    # na potrzeby obsługi case'u powtórzeń (gdy ten sam obraz jest wymieniony w wielu maszynach, czyli praktycznie zawsze)
    # robimy grupowanie po nazwie (stad i.id... a nie i.id), a odwolujac sie do tego pobieramy pierwszy element z listy (.0)
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
