variable "environment" {
    type = string
    description = "Environment name, used to prefix names"
}

variable "key_pair" {
    type = string
    description = "Openspace public key name"
}

variable "machines" {
    type = any
#    map(object({
#        flavor_name = string
#        image_name = string
#        volume_size = number
#        volume_type = optional(string)
#        fixed_ip = optional(string)
#        floating_ip = optional(string)
#        availability_zone = optional(string)
#        network_name = optional(string)
#        security_groups = list(string)
#        attach_volumes = optional(list(string))
#        server_group = optional(string)
#    }))
    description = "Machine definitions"
}
