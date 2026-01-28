#!/bin/bash

set -e

echo "Deploying Payflow monitoring stack into the monitoring namespace..."

echo "1) Applying namespace..."
kubectl apply -f k8s/monitoring/namespace.yaml

echo "2) Applying Prometheus resources..."
kubectl apply -f k8s/monitoring/prometheus

echo "3) Applying Loki resources..."
kubectl apply -f k8s/monitoring/loki

echo "4) Applying Grafana resources..."
kubectl apply -f k8s/monitoring/grafana

echo "5) Applying Promtail resources..."
kubectl apply -f k8s/monitoring/promtail

echo "Waiting for deployments to become ready..."
kubectl rollout status deployment/prometheus -n monitoring
kubectl rollout status deployment/loki -n monitoring
kubectl rollout status deployment/grafana -n monitoring

echo "Monitoring stack is deployed."
echo ""
echo "Access (port-forward):"
echo "  Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "  Grafana:    kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "  Loki:       kubectl port-forward -n monitoring svc/loki 3100:3100"
