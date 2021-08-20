module "test-cluster" {
    source = "./cluster"

    environment = "test"                    # environment is used for prefixing resource names
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
