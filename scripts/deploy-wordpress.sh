#!/bin/bash

# Set variables
AWS_REGION="us-west-2"
CLUSTER_NAME="wordpress-cluster"

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Deploy WordPress
kubectl apply -f ../k8s-manifests/wordpress/

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress --timeout=300s

echo "WordPress deployment completed"
