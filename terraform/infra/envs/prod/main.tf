module "vpc" {
  source = "../../modules/vpc"

  project_id    = var.project_id
  env           = var.env
  region        = var.region
  vpc_cidr      = var.vpc_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
}

module "gke" {
  source = "../../modules/gke"

  project_id          = var.project_id
  env                 = var.env
  region              = var.region
  cluster_name        = "${var.env}-msef-gke"
  network             = module.vpc.network_name
  subnetwork          = module.vpc.subnet_name
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name

  node_machine_type = var.node_machine_type
  node_count        = var.node_count
  min_node_count    = var.min_node_count
  max_node_count    = var.max_node_count
}