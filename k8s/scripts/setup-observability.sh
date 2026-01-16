#!/bin/bash

echo "Setting up observability for payflow cluster..."

# Deploy metrics server
echo "Deploying metrics server..."
kubectl apply -f k8s/infrastructure/metrics-server.yaml

# Wait for metrics server to be ready
echo "Waiting for metrics server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system

# Verify observability commands
echo "Verifying observability setup..."

echo "1. Testing pod logs command..."
echo "   Command: kubectl logs <pod-name> -n payflow"
echo "   Example: kubectl logs $(kubectl get pods -n payflow -l app=redis -o jsonpath='{.items[0].metadata.name}') -n payflow"

echo "2. Testing resource description..."
echo "   Command: kubectl describe deployment redis -n payflow"

echo "3. Testing resource usage (may take a few minutes to populate)..."
echo "   Command: kubectl top pods -n payflow"
echo "   Command: kubectl top nodes"

echo "Observability setup complete!"
echo ""
echo "Available commands:"
echo "- View logs: kubectl logs <pod-name> -n payflow"
echo "- Describe resources: kubectl describe <resource-type> <resource-name> -n payflow"
echo "- Resource usage: kubectl top pods -n payflow"
echo "- Node usage: kubectl top nodes"