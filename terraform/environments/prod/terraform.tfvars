# terraform/environments/prod/terraform.tfvars

aws_region           = "us-west-2"
cluster_name         = "wordpress-cluster"
project_name         = "wordpress-eks"
environment          = "prod"
db_password          = "ChangeMe123!"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
wordpress_replicas   = 2

kubernetes_version = "1.28"
instance_types    = ["t3.medium"]
desired_size      = 2
max_size         = 4
min_size         = 1

vpc_cidr               = "10.0.0.0/16"
public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs   = ["10.0.10.0/24", "10.0.20.0/24"]