# Argo CD Bootstrap

Argo CD is bootstrapped automatically by the `terraform-cicd` pipeline as the final step of `health_platform`, via SSM into the bastion. You do not need to run these commands manually on a normal deploy.

## Manual bootstrap (break-glass only)

If you need to re-bootstrap outside of the pipeline, run these from the bastion:

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.14.9/manifests/install.yaml
kubectl -n argocd wait --for=condition=Available deployment/argocd-server --timeout=5m
kubectl apply -n argocd -f k8s/argocd/apps/app-of-apps.yaml
```

## Install Apps (App of Apps)

The app-of-apps manifest creates per-environment Argo CD Applications under `k8s/argocd/apps/`.
All steps are idempotent — safe to re-run.

