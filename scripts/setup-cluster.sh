#!/bin/bash

# Set variables
AWS_REGION="us-west-2"
CLUSTER_NAME="wordpress-cluster"

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Create namespace
kubectl apply -f ../k8s-manifests/namespace.yaml

# Create storage class
kubectl apply -f ../k8s-manifests/efs/storageclass.yaml

# Create MySQL resources
kubectl apply -f ../k8s-manifests/mysql/

# Create Redis resources
kubectl apply -f ../k8s-manifests/redis/

echo "Cluster setup completed"
