#!/usr/bin/env bash
aws eks update-kubeconfig --name payflow-eks-dev --region us-east-1



export KUBECONFIG=/tmp/kubeconfig
aws eks update-kubeconfig --name payflow-eks-dev --region us-east-1

# Verify CRDs are established
kubectl wait --for=condition=Established crd/externalsecrets.external-secrets.io --timeout=120s
kubectl wait --for=condition=Established crd/clustersecretstores.external-secrets.io --timeout=120s

# Verify API resources are visible
kubectl api-resources --api-group=external-secrets.io

# Then apply
kubectl apply -k /home/ssm-user/k8s-payflow/overlays/dev
