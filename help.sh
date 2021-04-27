#!/bin/bash

if [ ! -f credentials.auto.tfvars ]; then
cat << EOF

For your convenience create a ./credentials.auto.tfvars with the following content

open_stack_user_name = "your-openstack-username"
open_stack_password = "your-openstack-password"

# This file is excluded from git through .gitignore

EOF

fi

cat << EOF

1. Edit credentials.auto.tfvars and terraform.tfvars and then run
   terraform init

2. To apply changes to your cluster run:
   terraform apply

3. To add a new environment, copy and edit environment-test.tf and then run
   terraform init
   terraform apply

EOF
