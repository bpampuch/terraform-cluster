output "volumes" {
    value = {
        for key, volume in openstack_blockstorage_volume_v3.volumes:
        key => volume
    }
    sensitive = true
}

output "instances" {
    value = {
        for key, instance in openstack_compute_instance_v2.instances:
        key => instance
    }
    sensitive = true
}

output "fixed_ips" {
    value = {
        for key, instance in openstack_compute_instance_v2.instances:
        key => instance.network.0.fixed_ip_v4
    }
    sensitive = true
}
