# terraform/environments/prod/main.tf

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
  # ... other configurations ...
}


# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "19.15.3"

#   cluster_name    = var.cluster_name
#   cluster_version = "1.27"

#   vpc_id                         = module.vpc.vpc_id
#   subnet_ids                     = module.vpc.private_subnets
#   cluster_endpoint_public_access = true

#   eks_managed_node_groups = {
#     default = {
#       min_size     = 1
#       max_size     = 3
#       desired_size = 2

#       instance_types = ["t3.medium"]
#     }
#   }

#   tags = {
#     Environment = "test"
#   }
# }

# module "efs" {
#   source = "../../modules/efs"
#   # ... configurations ...
#   depends_on = [module.vpc]
# }

# module "efs" {
#   source = "../../modules/efs"
  
#   project_name      = var.project_name
#   vpc_id           = module.vpc.vpc_id
#   private_subnet_ids = module.vpc.private_subnet_ids
# }

module "efs" {
  source = "../../modules/efs"
  
  project_name      = var.project_name
  vpc_id           = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  private_subnet_count = length(module.vpc.private_subnet_ids)
}



resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = module.eks.eks_managed_node_groups["default"].iam_role_name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = module.eks.eks_managed_node_groups["default"].iam_role_name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = module.eks.eks_managed_node_groups["default"].iam_role_name
}

# RDS for WordPress
resource "aws_db_subnet_group" "wordpress" {
  name       = "wordpress-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

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
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
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


