#!/bin/bash

# Set variables
AWS_REGION="us-west-2"
CLUSTER_NAME="wordpress-cluster"

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Delete all resources in namespace
kubectl delete namespace wordpress

# Delete Terraform resources
cd ../terraform/environments/prod
terraform destroy -auto-approve

echo "Cleanup completed"
