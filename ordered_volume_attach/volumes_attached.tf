# This is a workaround which overcomes the following Terraform limitations:
# - openstack_compute_volume_attach_v2 order is random (unless you specify depends_on)
# - depends_on cannot be based on any calculations (which makes it useless when combined with for_each)
# 
# Therefore we can't use for_each with openstack_compute_volume_attach_v2 because it is errorprone
# (eg. /dev/vdc can become /dev/vdb)

locals {
    normalized_volume_names = var.volume_names != null ? var.volume_names : []
}

data "openstack_blockstorage_volume_v3" "existing_volumes" {
    for_each = { for name in local.normalized_volume_names: name => name }
    name = each.value
}

resource "openstack_compute_volume_attach_v2" "va_1" {
    count = length(local.normalized_volume_names) > 0 ? 1 : 0

    instance_id = var.instance_id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[local.normalized_volume_names.0].id
}

resource "openstack_compute_volume_attach_v2" "va_2" {
    count = length(local.normalized_volume_names) > 1 ? 1 : 0

    instance_id = var.instance_id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[local.normalized_volume_names.1].id
    depends_on  = [openstack_compute_volume_attach_v2.va_1]
}

resource "openstack_compute_volume_attach_v2" "va_3" {
    count = length(local.normalized_volume_names) > 2 ? 1 : 0

    instance_id = var.instance_id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[local.normalized_volume_names.2].id
    depends_on  = [openstack_compute_volume_attach_v2.va_2]
}

resource "openstack_compute_volume_attach_v2" "va_4" {
    count = length(local.normalized_volume_names) > 3 ? 1 : 0

    instance_id = var.instance_id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[local.normalized_volume_names.3].id
    depends_on  = [openstack_compute_volume_attach_v2.va_3]
}


resource "openstack_compute_volume_attach_v2" "va_5" {
    count = length(local.normalized_volume_names) > 4 ? 1 : 0

    instance_id = var.instance_id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[local.normalized_volume_names.4].id
    depends_on  = [openstack_compute_volume_attach_v2.va_4]
}


resource "openstack_compute_volume_attach_v2" "va_6" {
    count = length(local.normalized_volume_names) > 5 ? 1 : 0

    instance_id = var.instance_id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[local.normalized_volume_names.5].id
    depends_on  = [openstack_compute_volume_attach_v2.va_5]
}

resource "openstack_compute_volume_attach_v2" "va_7" {
    count = length(local.normalized_volume_names) > 6 ? 1 : 0

    instance_id = var.instance_id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[local.normalized_volume_names.6].id
    depends_on  = [openstack_compute_volume_attach_v2.va_6]
}

resource "openstack_compute_volume_attach_v2" "va_8" {
    count = length(local.normalized_volume_names) > 7 ? 1 : 0

    instance_id = var.instance_id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[local.normalized_volume_names.7].id
    depends_on  = [openstack_compute_volume_attach_v2.va_7]
}

resource "openstack_compute_volume_attach_v2" "va_9" {
    count = length(local.normalized_volume_names) > 8 ? 1 : 0

    instance_id = var.instance_id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[local.normalized_volume_names.8].id
    depends_on  = [openstack_compute_volume_attach_v2.va_8]
}

resource "openstack_compute_volume_attach_v2" "va_10" {
    count = length(local.normalized_volume_names) > 9 ? 1 : 0

    instance_id = var.instance_id
    volume_id   = data.openstack_blockstorage_volume_v3.existing_volumes[local.normalized_volume_names.9].id
    depends_on  = [openstack_compute_volume_attach_v2.va_9]
}
