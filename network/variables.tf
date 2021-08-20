variable "environment" {
    type = string
}

variable "external_network_name" {
    type = string
    description = "External network name"
    default = "internal_ip_01"
}

variable "dns_servers" {
    type = list(string)
    description = "DNS server list"
}

variable "networks" {
    type = map(string)
    description = "List of networks and their first three octets, eg. 10.111.1"
}

variable "network_rules" {
#   The type should be declared as:
#     type = map(object({
#         in_tcp = optional(map(any))
#         in_udp = optional(map(any))
#     }))
#   however it fails if network_rules elements differ (eg. some contain in_udp while others don't) 
#
#   So unfortunately, to make it work, type checking is turned off with map(any)
    type = map(any)
    description = "Security group and rules"
    default = {}
}

# 
# variable "network_rules" {
#     type = object({
#         in_tcp = optional(map(any))
#         in_udp = optional(map(any))
#     })
#     description = "Security group and rules"
#     default = { }
# }
