project_id = "msef-2026"
env        = "stg"
region     = "us-central1"

vpc_cidr      = "10.40.0.0/20"
pods_cidr     = "10.50.0.0/16"
services_cidr = "10.60.0.0/20"

node_machine_type = "e2-standard-4"
node_count        = 2
min_node_count    = 1
max_node_count    = 3