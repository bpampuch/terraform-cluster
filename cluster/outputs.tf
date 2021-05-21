output "instances" {
    value = module.instance.instances
    sensitive = true
}

# output "instances" {
#     value = {
#         for key, instance in openstack_compute_instance_v2.instances:
#         key => instance
#     }
#     sensitive = true
# }

# output "fixed_ips" {
#     value = {
#         for key, instance in openstack_compute_instance_v2.instances:
#         key => instance.network.0.fixed_ip_v4
#     }
#     sensitive = true
# }
