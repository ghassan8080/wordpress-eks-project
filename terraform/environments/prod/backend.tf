terraform {
  backend "s3" {
    bucket = "ghassan8080-wordpress-eks-project"
    key    = "wordpress-eks/terraform.tfstate"
    region = "us-west-2"
  }
}
