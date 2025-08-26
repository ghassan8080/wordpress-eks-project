# terraform/environments/prod/backend.tf
# Create this file to explicitly configure the backend

terraform {
  backend "s3" {
    bucket = "ghassan8080-wordpress-eks-project"
    key    = "wordpress-eks/terraform.tfstate"
    region = "us-west-2"
    
    # Optional: Enable state locking and consistency checking
    # dynamodb_table = "terraform-state-lock"
    # encrypt        = true
  }
}