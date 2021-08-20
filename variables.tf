variable "open_stack_project_name" { 
  type = string 
  description = "project_name from clouds.yaml"
}

variable "open_stack_auth_url" { 
  type = string 
  description = "auth_url from clouds.yaml"
}

variable "open_stack_region" { 
  type = string 
  description = "openstack region name"
}

variable "open_stack_user_domain_name" { 
  type = string 
  description = "user_domain_name from clouds.yaml"
  default = "IPA"
}

variable "open_stack_user_name" { 
  type = string 
  description = "Username to your openstack account"
}

variable "open_stack_password" { 
  type = string
  description = "Password to your openstack account"
  sensitive = true
}

variable "dns_list" { 
  type = list(string)
  description = "List of DNS addresses"
  default = []
}