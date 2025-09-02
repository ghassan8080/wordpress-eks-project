# terraform/environments/prod/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "5.0.0"

#   name = "wordpress-vpc"
#   cidr = "10.0.0.0/16"

#   azs             = ["us-west-2a", "us-west-2b"]
#   private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
#   public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

#   enable_nat_gateway = true
#   single_nat_gateway = true
#   enable_vpn_gateway = false

#   tags = {
#     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
#   }

#   public_subnet_tags = {
#     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
#     "kubernetes.io/role/elb"                    = "1"
#   }

#   private_subnet_tags = {
#     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
#     "kubernetes.io/role/internal-elb"           = "1"
#   }
# }

module "vpc" {
  source = "../../modules/vpc"
  
  project_name         = var.project_name
  cluster_name         = var.cluster_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_count = var.public_subnet_count
  private_subnet_count = var.private_subnet_count
  single_nat_gateway  = var.single_nat_gateway
  
  tags = {
    Environment = var.environment
    Project    = var.project_name
  }

  depends_on = [null_resource.cleanup_kubernetes]
}

# Cleanup Kubernetes resources before destroying the cluster
resource "null_resource" "cleanup_kubernetes" {
  triggers = {
    cluster_name = var.cluster_name
    region       = var.aws_region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Cleaning up Kubernetes resources..."
      # Delete application resources
      kubectl delete namespace wordpress --ignore-not-found=true --timeout=5m

      # Delete EKS addons
      kubectl delete -f ../../k8s-manifests/aws-load-balancer-controller.yaml --ignore-not-found=true --timeout=5m
      kubectl delete -f ../../k8s-manifests/efs/efs-csi-driver.yaml --ignore-not-found=true --timeout=5m
      kubectl delete -f ../../k8s-manifests/efs/efs-storageclass.yaml --ignore-not-found=true --timeout=5m

      # Wait for loadbalancer resources to be deleted
      echo "Waiting for LoadBalancer resources to be deleted..."
      kubectl get svc -A | Select-String -Pattern "LoadBalancer" | ForEach-Object {
        $ns = $_.ToString().Split()[0]
        $svc = $_.ToString().Split()[1]
        kubectl delete svc $svc -n $ns --timeout=5m
      }

      # Remove finalizers from any stuck resources
      echo "Cleaning up any stuck resources..."
      kubectl get namespace wordpress -o json | ConvertTo-Json | ForEach-Object { $_ -replace '"finalizers": \[[^\]]*\]', '"finalizers": []' } | kubectl replace --raw "/api/v1/namespaces/wordpress/finalize" -f -

      echo "Kubernetes resources cleanup completed"
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
}


module "eks" {
  source = "../../modules/eks"
  
  cluster_name     = var.cluster_name
  vpc_id           = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  
  depends_on = [null_resource.cleanup_kubernetes]
  
  kubernetes_version = var.kubernetes_version
  capacity_type      = var.capacity_type
  instance_types     = var.instance_types
  ami_type           = var.ami_type
  disk_size          = var.disk_size
  
  desired_size = var.desired_size
  max_size     = var.max_size
  min_size     = var.min_size
  
  tags = {
    Environment = var.environment
    Project    = var.project_name
  }
}

# module "efs" {
#   source = "../../modules/efs"
#   # ... configurations ...
#   depends_on = [module.vpc]
# }

module "efs" {
  source = "../../modules/efs"
  
  project_name            = var.project_name
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  private_subnet_count   = length(module.vpc.private_subnet_ids)
  node_security_group_id = module.eks.node_group_security_group_id
  allow_nodes_sg_ingress = true
  
  tags = {
    Environment = var.environment
    Project    = var.project_name
  }
}





# RDS for WordPress
resource "aws_db_subnet_group" "wordpress" {
  name       = "wordpress-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Name = "WordPress DB Subnet Group"
  }
}

resource "aws_security_group" "rds" {
  name        = "wordpress-rds-sg"
  description = "Allow WordPress EKS to access RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-rds-sg"
  }
}

resource "aws_db_instance" "wordpress" {
  identifier           = "wordpress-db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  storage_type         = "gp2"
  storage_encrypted    = true
  db_name              = "wordpress"
  username             = "admin"
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
  db_subnet_group_name = aws_db_subnet_group.wordpress.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot  = true
  multi_az             = false

  tags = {
    Name = "WordPress DB"
  }
}

# EKS Kubernetes resources
resource "kubernetes_namespace" "wordpress" {
  metadata {
    name = "wordpress"
  }
}

resource "kubernetes_secret" "wordpress_db" {
  metadata {
    name      = "wordpress-db-secret"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  data = {
    WORDPRESS_DB_HOST = aws_db_instance.wordpress.address
    WORDPRESS_DB_USER = aws_db_instance.wordpress.username
    WORDPRESS_DB_PASSWORD = aws_db_instance.wordpress.password
    WORDPRESS_DB_NAME = aws_db_instance.wordpress.db_name
  }
}

resource "kubernetes_deployment" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          name  = "wordpress"
          image = "wordpress:latest"
          port {
            container_port = 80
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.wordpress_db.metadata[0].name
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  spec {
    selector = {
      app = "wordpress"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

# Add provider configuration
# provider "aws" {
#   region = var.aws_region
# }

  

# module "efs" {
#   source = "../../modules/efs"
  
#   cluster_name         = var.cluster_name
#   vpc_id              = module.vpc.vpc_id
#   subnet_ids          = module.vpc.private_subnets
#   cluster_security_group_id = module.eks.cluster_security_group_id
#   # ... other variables
# }


