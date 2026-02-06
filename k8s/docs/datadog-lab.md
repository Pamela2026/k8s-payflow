# Datadog Lab (Isolated From Current Monitoring)

This setup is intentionally separate from `k8s/helm-values/monitoring`.

## What is isolated
- Separate Helm values: `k8s/helm-values/datadog/datadog-values.yaml`
- Separate namespace: `datadog-lab`
- Separate Helm release: `datadog-lab`
- Separate secret for keys: `datadog-keys`

## Install
```bash
./k8s/scripts/install-datadog-lab.sh <DATADOG_API_KEY> <DATADOG_APP_KEY>
```

## Verify
```bash
kubectl get pods -n datadog-lab
helm list -n datadog-lab
```

## Uninstall (clean rollback)
```bash
helm uninstall datadog-lab -n datadog-lab
kubectl delete namespace datadog-lab
```
