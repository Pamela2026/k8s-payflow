# Argo CD Bootstrap

This folder contains Argo CD application definitions used for GitOps.

Because the EKS API is private-only, run all bootstrap commands from the bastion.

## Install Argo CD

Option A (kubectl apply upstream manifest):

```bash
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Option B (Helm) is also fine if you prefer pinned chart versions.

## Install Apps (App of Apps)

```bash
kubectl apply -n argocd -f k8s/argocd/apps/app-of-apps.yaml
```

This will create per-environment Argo CD Applications under `k8s/argocd/apps/`.

