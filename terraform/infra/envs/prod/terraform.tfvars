project_id = "msef-2026"
env        = "prod"
region     = "us-central1"

vpc_cidr      = "10.70.0.0/20"
pods_cidr     = "10.80.0.0/16"
services_cidr = "10.90.0.0/20"

node_machine_type = "e2-standard-4"
node_count        = 3
min_node_count    = 2
max_node_count    = 5