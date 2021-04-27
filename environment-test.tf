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
                "10.132.0.0/24": [ 22 ]     # keys are remote cidrs, values are ports lists which should be allowed
            }
            #in_udp = {}                    # udp rules can be defined as well
        }
        front = { 
            # allow ingress tcp from bastion network on port 22
            # allow ingress tcp from any on ports 80, 443, 1000-2000
            in_tcp = { 
                "bastion": [ 22 ]                       # instead of cidrs you can also use network keys (as defined above)
                "0.0.0.0/0": [ 80, 443, "1000-2000" ]   # not only ports, but also port ranges can be used (using strings with dash)
            } 
        }
        app = { 
            # allow ingress tcp from bastion network on port 22
            # allow ingress tcp from front network on port 80
            in_tcp = { 
                "bastion": [ 22 ]
                "front": [ 80 ] 
            } 
        }
        db = { 
            # allow ingress tcp from bastion network on port 22
            # allow ingress tcp from app network on ports 6379 and 27017
            in_tcp = { 
                "bastion": [ 22 ]
                "app": [ 27017, 6379 ] 
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
