# Intro
The aim of this project is to simplify terraform configuration for OpenStack provider:

```hcl
module "test-cluster" {
    source = "./cluster"

    environment = "test"                        # environment is used for prefixing resource names
    dns_servers = ["8.8.8.8"]
    key_pair = "you_keypair_name"

    network_rules = {
        xyz = {
            in_tcp = {
                # allow incoming TCP on port 123 from 10.132.0.0/24
                "10.132.0.0/24" = [ 123 ]     
            }
            # in_udp = {}
        }
    }

    cluster = {
        bastion = {
            network = "10.110.1.0/24"             
            flavor_name = "C1R2"
            volume_size = 20
            # volume_type = "io-nvme"           # optional volume type
            # availability_zone = "az1"         # optional availability zone
            image_name = "Centos-8-2004"
            # generate_fip = true               # optional if you want generate FIPs (default: false)
            floating_ips = [ "10.100.23.11" ]   # optional if you want to associate FIPs
            #fixed_ips = [ "10.111.1.100" ]     # optional if you want to set fixed IPs manually
            open_tcp_ports_for = {
                "10.100.0.0/24": [ 22 ]
            }
            # open_udp_ports_for = ...
            security_groups = ["xyz"]
        }
        nginx = {
            network = "10.110.2.0/24"
            flavor_name = "C2R4"
            image_name = "Centos-8-2004"
            volume_size = 20
            count = 2
            floating_ips = [ "10.100.23.122", "10.100.23.123" ]
            #fixed_ips = [ "10.111.2.100", "10.111.2.101" ]      # optional
            open_tcp_ports_for = {
                "bastion": [ 22 ]
                "0.0.0.0/0": [ 80, 443 ]
            }
            security_groups = ["xyz"]
        }
        application = {
            network = "10.110.3.0/24"
            flavor_name = "C4R8"
            image_name = "Centos-8-2004"
            volume_size = 20
            count = 2
            open_tcp_ports_for = {
                "bastion": [ 22 ]
                "nginx": [ 80 ]
            }
        }
        mongo = {
            network = "10.110.4.0/24"
            flavor_name = "C4R8"
            image_name = "Centos-8-2004"
            volume_size = 20
            count = 3
            open_tcp_ports_for = { 
                "bastion" = [22], 
                "application" = [27017] 
                "mongo" = [27017]
            } 
            
            fixed_ip = ["10.111.4.100", "10.111.4.101", "10.111.4.102"]
            attach_volumes = [ ["fast_db_volume_1"], ["fast_db_volume_2"], ["fast_db_volume_3"] ]
            availability_zone = "az1"
        }
    }
}
```

## Input Variables
* `environment` - used to prefix resource names (to distinguish them between various environments)
* `dns_servers` - a list of dns servers
* `key_pair` - name of public key uploaded to openstack
* `network_rules` - a list of general security groups
* `cluster` - a "map" with named groups, where each group contains the following fields:
  * `network` -  network for this group (eg. "10.110.1.0/24")
  * `flavor_name` - flavor name for instances in this group (eg. "C1R2")
  * `volume_size` - size of bootable volumes created for each instance in this group
  * `image_name` - base image name for volumes in this group (eg. "Centos-8-2004")
  * `volume_type` - optional volume type (eg. 'io-nvme' if your openstack installation supports it)
  * `availability_zone` - optional availability zone for this group
  * `count` - optional number of compute instances to be spawned (default: 1)
  * `open_tcp_ports_for` - an optional set of security group rules for the tcp protocol (as described below)
  * `open_udp_ports_for` - an optional set of security group rules for the udp protocol (as described below)
  * `security_groups` - a list of general security groups
  * `fixed_ips` - an optional array of fixed ips for each instance (the array size should correspond to the `count` parameter)
  * `generate_fip` - an optional flag to generate FIP from pool `external_network_name`
  * `floating_ips` - an optional array of FIPs for reach instance (the array size should correspond to the `count` parameter)
  * `attach_volumes` - an array of arrays with volume names which are supposed to be attached to particular instances in this group (refer to the description below for further information)

## Resources
The module creates a new *openstack_networking_router_v2* connected to the external network and then, for each subelement of `cluster`, the following set of resources:
   * a *openstack_networking_network_v2*, a *openstack_networking_subnet_v2* and a *openstack_networking_router_interface_v2* for the subnetwork (based on `network`)
   * an *openstack_networking_secgroup_v2* with:
     * **allow-all-out** rules for TCP/UDP/ICMP
     * an optional set of **allow-in-tcp** rules based on `open_tcp_ports_for`
     * an optional set of **allow-in-udp** rules based on `open_udp_ports_for`
   * an *openstack_compute_servergroup_v2* with **anti-affinity** policy
   * a `count` number of
     * `openstack_blockstorage_volume_v3` with
        * `volume_size` size, 
        * base `image_name` image
        * an optional `availability_zone`
        * an optional `volume_type`
        * enable_online_resize set to true
     * `openstack_compute_instance_v2` with
        * `flavor_name` flavor name
        * `key_pair` key pair name
        * security group set to the group created above, based on `open_tcp_ports_for` and `open_udp_ports_for` (refer to the description below for further information)
        * a binding to the appropriate network created above
        * scheduler_hints.group set to the anti-affinity server group created aboce
        * an optional fixed_ip (as described below)
        * an optional `availability_zone`
        * an optional set of `openstack_compute_floatingip_associate_v2` (as described below)
        * an optional set of `openstack_compute_volume_attach_v2` (as described below)

## Security Groups and Rules
There are several ways to shape security groups and their granularities. 

This module creates a single security group for each network and instances running in that network. 

By default it allows all out (egress) traffic and limits ingress based on rules defined in `open_tcp_ports_for` and `open_udp_ports_for`:
```
open_tcp_ports_for = {
    "remote_ip": [ port_number, port_number2, "port-range" ]
    "another_remote_ip": [ port_number3 ]
}
```
* each key represents a remote_ip, which can be:
  * a CIDR (eg. "0.0.0.0/0") or 
  * the name of a group from `cluster` definition - in such case it will turn into `${network}`
* each value is an array of ports to be opened. Array elements can be port numbers or port ranges (strings with a dash, eg "10000-20000")

## Fixed IPs and Floating IPs
You can provide an array of `fixed_ips` or `floating_ips` if you want to assign them to the instances.

At the moment it's not possible to assign more than one fixed_ip and one FIP to a single instance.

Therefore the size of fixed_ips and floating_ips arrays should equal `count` parameter for each cluster group.

## Attached Volumes
Since accidental removal of resources with Terraform can happen if you're not careful enough, it's common to manage some volumes (eg. databases) externally.

You can attach such volumes to instances created with this module using attach_volumes
```
attach_volumes = [ ["fast_db_volume_1"], ["fast_db_volume_2"], ["fast_db_volume_3"] ]
```
Each element of the external array corresponds to a particular compute instance, therefore the size of this array should equal `count` parameter.
Each inner array is a set of volume names which should be attached to the compute instance.

Because of current Terraform limitations it's unsafe to use openstack_blockstorage_volume_v2 with for_each (this is errorprone
and can change the order of volumes, eg. /dev/vdb can become /dev/vdc). This module has a workaround to preserve the order, but 
limits the amount of volumes which can be attached to a single compute instance to 10. 

Imagine we create 4 compute instances (`count` = 4) and we want to attach two "external" volumes for each instance (one for logs and another for db data). Assuming their names are logs1, db1, logs2, db2, logs3, db3, logs4, db4 we can do this with the following syntax:
```
attach_volumes = [ ["logs1", "db1"], ["logs2", "db2"], ["logs3", "db3"], ["logs4", "db4"] ]
```

# Submodules
Cluster module leverages two other modules from this repository
* **Network** which lets you quickly define networks, security groups and rules
* **Instance** - a convenient shortcut for compute instances, volumes and Floating IP associations

# Network Module
## Input Variables

## Usage
```hcl
module "test-net" {
    source = "./network"

    environment = "test"
    # external_network_name = "internal_ip_01"
    dns_servers = ["8.8.8.8"]

    networks = {
        bastion = "10.111.1"
        front = "10.111.2"
        app = "10.111.3"
        db = "10.111.4"
    }

    network_rules = {
        bastion = {
            in_tcp = {
                # allow incoming TCP on port 22 from 10.132.0.0/24
                "10.132.0.0/24" = [ 22 ]     
            }
            # in_udp = {}
        }
        front = {
            in_tcp = {
                # allow incoming TCP on port 22 from the bastion network 
                "bastion" = [ 22 ]

                # allow incoming TCP on 80/443 from any
                "0.0.0.0/0" = [ 80, 443 ]    
            }
            # in_udp = {}
        }
        app = {
            in_tcp = {
                # allow incoming TCP on 22 from the bastion network
                "bastion" = [ 22 ]

                # allow incoming TCP on 80 and 1000-2000 range from the front network
                "front" = [ 80, "1000-2000" ]
            }
            # in_udp = {}
        }
        db = {
            in_tcp = {
                # allow incoming TCP on 22 from the bastion network
                "bastion" = [ 22 ]

                # allow incoming TCP on 27017 from the app network
                "app" = [ 27017 ]
            }
            # in_udp = {}
        }
    }
```
* always use 3 octets when you define networks with this module - we assume all internal networks are /24
* one router (for all networks) will be created
* one subnet for each network will be created
* each key in `network_rules` will be mapped to a security group - you can leverage this as you wish, however it's convenient to have a group per network
* at the moment the module automatically adds allow_all_out (tcp/udp/icmp traffic) to each security group - you can only manage ingress rules - this will be extended in the future
* `in_tcp` and `in_udp` objects have the following structure
    * *keys* define source (they're mapped to remote_ip_prefix of `openstack_networking_secgroup_rule_v2`) - you can use CIDRs here or, for convenience, also network keys (eg. bastion),
    * *values* are lists of ports (numbers) or port-ranges (eg. "100-200") - each list element will be mapped to a `openstack_networking_secgroup_rule_v2`

## Output Variables
* `network_names` - a map of network keys and generated network names - use it when you need to access network names (eg. in compute instances)
    ```name = module.test-net.network_names.bastion```
* `networks` - a map of network keys and generated networks (in case you need to access `openstack_networking_network_v2` attributes)
    ```module.test-net.network_names.bastion.id```
* `cidrs` - a map of network keys and their CIDRs (useful if you manually define security group rules and don't want to use literals in remote_ip_prefixes)
* `security_group_names` - a map of network keys and generated security group names - use it to apply security groups to compute instances:
    ```security_groups = [module.test-net.security_group_names.bastion]```


# Instance Module
* `environment` - used only as a prefix for resource names (to distinguish between various environments)
* `key_pair` - you uploaded public key name
* `machines` - a map of machines with the following sub-object keys
    * **image_name** - mandatory base image name for the volume (eg "Centos-8-2004")
    * **volume_size** - mandatory volume size in GB
    * volume_type - optional volume type (eg. `io-nvme`)
    * flavor_name - optional compute instance flavor name (eg. "C2R4") - if not provided - no instance resouce will be created (clear it if you wish to remove the instance but preserve the volume)
    * fixed_ip - optional fixed IP
    * floating_ip - optional Floating IP to be assigned to this instance
    * availability_zone - optional (but required in case you set volume_type)
    * network_name - optional network name you want to attach this instance to
        * if you use this with the Network module, you will probably leverage `network_names` output (eg. ```module.test-net.network_names.bastion```)
    * attach_volumes - a list of volume names which should be attached
    * security_groups - a list of security group names
        * if you use this with the Network module, you will probably leverage `security_group_names` output (eg. ```security_groups = [module.test-net.security_group_names.bastion]```)

## Usage
```hcl
module "test-cluster" {
    source = "./cluster"

    environment = "test"
    key_pair = "your_keypair_name"

    machines = {
        bastion = {
            flavor_name = "C1R2"
            image_name = "Centos-8-2004"
            volume_size = 20
            # volume_type = "io-nvme"
            availability_zone = "az1"
            floating_ip = "10.232.11.221"
            fixed_ip = "10.111.1.100"           # this is optional
            network_name = module.test-net.network_names.bastion
            security_groups = [module.test-net.security_group_names.bastion]
        }
        nginx = {
            flavor_name = "C2R4"
            image_name = "Centos-8-2004"
            volume_size = 20
            availability_zone = "az1"
            fixed_ip = "10.111.1.101"
            floating_ip = "10.232.22.145"
            network_name = module.test-net.network_names.front
            security_groups = [module.test-net.security_group_names.front]
        }
        (...)
    }
}
```
* all compute instances will automatically have `UseDNS no` set `/etc/ssh/sshd_config`
* each instance will automatically attach a corresponding volume (at the moment there's always 1-to-1 binding, no multiattached volumes are allows - this might change in the future)
* **WARNING!** Don't change local module names nor environment names when you use Cluster and Network modules as this will recreate all resources declared by these modules.

## Output variables
* `volumes` - a map of machine keys and the generated volumes `openstack_blockstorage_volume_v3` - useful if you manually create instances and want to attach volumes created by this module
* `instances` - a map of machine keys and the generated `openstack_compute_instance_v2`
* `fixed_ips` - a map of machine keys and their IPv4 addresses

# Quick Start
1. Clone this repository
2. Fill in terraform.tfvars based on clouds.yaml from your OpenStack project
3. Add credentials.auto.tfvars with the following content
```
open_stack_user_name = "USERNAME"
open_stack_password = "PASSWORD"
```
4. Edit environment-test.tf (or copy it in case additional environments are expected)
5. Run
```
terraform init
terraform apply
```
## An example leveraging Network and Instance modules

```hcl
module "test-net" {
    source = "./network"

    environment = "test"                    # environment is used for prefixing resource names
    dns_servers = var.dns_list

    networks = {                            # always use 3 IP octets when you define networks with this module
        bastion = "10.111.1"
        front = "10.111.2"
        app = "10.111.3"
        db = "10.111.4"
    }

    network_rules = {
        bastion = {                         # security group key

            # allow ingress tcp from (10.132.0.0/24) on port 22
            in_tcp = {                      # ingress rules for TCP
                "10.132.0.0/24" = [ 22 ]     # keys are remote cidrs, values are ports lists which should be allowed
            }
            #in_udp = {}                    # udp rules can be defined as well
        }
        front = { 
            # allow ingress tcp from bastion network on port 22
            # allow ingress tcp from any on ports 80, 443, 1000-2000
            in_tcp = { 
                "bastion" = [ 22 ]                       # instead of cidrs you can also use network keys (as defined above)
                "0.0.0.0/0" = [ 80, 443, "1000-2000" ]   # not only ports, but also port ranges can be used (using strings with dash)
            } 
        }
        app = { 
            # allow ingress tcp from bastion network on port 22
            # allow ingress tcp from front network on port 80
            in_tcp = { 
                "bastion" = [ 22 ]
                "front" = [ 80 ] 
            } 
        }
        db = { 
            # allow ingress tcp from bastion network on port 22
            # allow ingress tcp from app network on ports 6379 and 27017
            in_tcp = { 
                "bastion" = [ 22 ]
                "app" = [ 27017, 6379 ] 
            } 
        }
    }
}

module "test-cluster" {     # << DON'T change this name after deployment, as it will remove whole cluster
    source = "./cluster"

    environment = "test"    # <<< DON'T change this name either, otherwise you'll loose the whole cluster
    key_pair = "your_keypair_name"

    machines = {
        bastion = {
            flavor_name = "C1R2"                # if no flavor_name is provided, only volume will be created
            image_name = "Centos-8-2004"
            volume_size = 20
            # volume_type = "io-nvme"           # optional volume_type for fast storage
            availability_zone = "az1"           # this is required for io-nvme
            floating_ip = "10.100.20.30"        # this is optional - only if you want to associate a floating ip
            fixed_ip = "10.111.1.100"           # this is optional
            network_name = module.test-net.network_names.bastion    # you can get a generated network name by network key
                                                                    # from network module outputs
            security_groups = [module.test-net.security_group_names.bastion]    # you can get a generated security group name
                                                                                # by network_rules key from network module outputs
        }
        nginx = {
            flavor_name = "C1R2"
            image_name = "Centos-8-2004"
            volume_size = 20
            availability_zone = "az1"
            fixed_ip = "10.111.1.101"
            network_name = module.test-net.network_names.front
            security_groups = [module.test-net.security_group_names.front]
        }
        app1 = {
            flavor_name = "C1R2"
            image_name = "Centos-8-2004"
            volume_size = 20
            volume_type = "io-nvme"
            availability_zone = "az1"
            fixed_ip = "10.111.1.102"
            network_name = module.test-net.network_names.app
            security_groups = [module.test-net.security_group_names.app]
        }
        mongo = {
            flavor_name = "C2R4"
            image_name = "Centos-8-2004"
            volume_size = 20
            fast_volume = false
            availability_zone = "az1"
            fixed_ip = "10.111.1.103"
            network_name = module.test-net.network_names.db
            security_groups = [module.test-net.security_group_names.db]
        }
    }
}

```
