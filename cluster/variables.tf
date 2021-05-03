variable "environment" {
    type = string
    description = "Environment name, used to prefix names"
}

variable "key_pair" {
    type = string
    description = "Openspace public key name"
}

variable "dns_servers" {
    type = list(string)
    description = "List of DNS servers"
}

variable "cluster" {
    #   The type should be declared as:
    #     map(object({
    #        net_prefix = string
    #        count = optional(number)
    #        flavor_name = string
    #        image_name = optional(string)
    #        volume_size = optional(number)
    #        volume_type = optional(string)
    #        open_tcp_ports_for = optional(map(any))
    #        open_udp_ports_for = optional(map(any))
    #        fixed_ips = optional(list(string))
    #        floating_ips = optional(list(string))
    #        attached_volumes = optional(list(list(string)))
    #        availability_zone = optional(string)
    #    }))
    #   however it fails if elements differ (eg. some contain open_udp_ports_for while others don't) 
    #
    #   So unfortunately, to make it work, type checking is turned off with map(any)
    type = any
    description = "Cluster definition"
}
