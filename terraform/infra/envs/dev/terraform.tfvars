project_id = "msef-2026"
env        = "dev"
region     = "us-east5"

vpc_cidr      = "10.10.0.0/20"
pods_cidr     = "10.20.0.0/16"
services_cidr = "10.30.0.0/20"

node_machine_type = "e2-standard-2"
node_count        = 2
min_node_count    = 1
max_node_count    = 3