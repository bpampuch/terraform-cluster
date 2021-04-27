This projects provides two modules which simplify terraform configuration for OpenStack provider:
* **Network** lets you quickly define networks, security groups and rules
* **Cluster** is a convinient shortcut for compute instances, volumes and Floating IP associations

I'll probably split them into two projects and upload to Terraform Registry in the future

# Network Module
## Input Variables
* `environment` - used only as a prefix for resource names (to distinguish between various environments)
* `external_network_name` - external network name (defaults to internal_ip_01)
* `dns_servers` - a list of dns servers (later passed to subnets)
* `networks` - a map of network keys and 3-octed IP prefixes
* `network_rules` - definition of security groups and rules

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


# Cluster Module
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
# Complete example

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
        concierge = {
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
