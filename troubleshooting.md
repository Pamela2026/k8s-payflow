# Kubernetes Troubleshooting Guide (Payflow)

Use this guide to diagnose common connectivity and routing issues in this cluster.
It is organized by OSI layer to help you isolate where failures occur.

## Quick triage checklist

1) Confirm pods are running and ready:
   - `kubectl -n payflow get pods`
2) Confirm services and endpoints exist:
   - `kubectl -n payflow get svc`
   - `kubectl -n payflow get endpoints`
3) Confirm ingress rules and addresses:
   - `kubectl -n payflow get ingress`
4) Review recent events:
   - `kubectl -n payflow get events --sort-by=.lastTimestamp`

## L7: Application (HTTP routing, paths, hosts)

Symptoms:
- `502 Bad Gateway`, `404 Not Found`, wrong host/path routing.

Checks:
- Ingress rules: `k8s/ingress/http-ingress.yaml`, `k8s/ingress/tls-ingress-payflow.yaml`
- API gateway routes and health endpoints.

Commands:
- `kubectl -n payflow describe ingress`
- `kubectl -n payflow logs deploy/api-gateway`

Fix patterns:
- Ensure host/path match client requests.
- Verify rewrite annotations if using `nginx.ingress.kubernetes.io/rewrite-target`.

## L6: Presentation (TLS, certs)

Symptoms:
- TLS handshake errors, browser security warnings.

Checks:
- TLS config in `k8s/ingress/tls-ingress-payflow.yaml`.

Commands:
- `kubectl -n payflow describe ingress`

Fix patterns:
- Update certs/secret references.
- Ensure hostnames match cert SANs.

## L5: Session (sticky sessions, long-lived connections)

Symptoms:
- WebSocket disconnects, login sessions dropping.

Checks:
- Ingress annotations or LB settings for session affinity.

Fix patterns:
- Avoid sticky sessions unless required.
- Ensure timeouts are appropriate for long-lived connections.

## L4: Transport (ports, service mapping)

Symptoms:
- `connection refused`, timeouts, `502 Bad Gateway` due to upstream failures.

Checks:
- Service ports/targetPorts: `k8s/services/all-services.yaml`
- Container listening ports: `k8s/deployments/*.yaml`
- NetworkPolicy ports: `k8s/policies/network-policies.yaml`

Commands:
- `kubectl -n payflow describe svc api-gateway`
- `kubectl -n payflow get endpoints api-gateway -o wide`

Fix patterns:
- Match `targetPort` to container `containerPort`.
- Example: API Gateway listens on `3000`, service should be `port: 80` and `targetPort: 3000`.

## L3: Network (routing, pod-to-pod connectivity)

Symptoms:
- `no route to host`, cross-node pod connectivity issues.

Checks:
- CNI plugin health (outside repo).

Commands:
- `kubectl -n payflow exec -it <pod> -- sh`
- From inside the pod: `ping <service>` or `curl http://<service>:<port>`

Fix patterns:
- Verify cluster pod/service CIDRs do not overlap.
- Ensure CNI is running on all nodes.

## L2: Data Link (MTU/VLAN)

Symptoms:
- Large payloads failing, intermittent packet loss.

Checks:
- CNI and node MTU settings.

Fix patterns:
- Align MTU across nodes and overlay networks.

## L1: Physical (nodes, NICs)

Symptoms:
- Node not ready, link flaps, hardware errors.

Checks:
- Cloud provider status or node system logs.

Commands:
- `kubectl get nodes -o wide`

## Common issues and fixes

### 1) API Gateway 502 via Nginx
Cause:
- Service port mismatch between nginx and API Gateway.
Fix:
- Ensure `api-gateway` service uses `port: 80` and `targetPort: 3000`.

### 2) Frontend calls localhost
Symptom:
- `POST http://localhost:3000/api/auth/login net::ERR_CONNECTION_REFUSED`
Cause:
- Frontend built with `http://localhost:3000` API base URL.
Fix:
- Rebuild and redeploy with `REACT_APP_API_URL=/api`.
- Ensure nginx proxies `/api` to `http://api-gateway.payflow.svc.cluster.local`.

### 3) ResourceQuota / LimitRange blocks (jobs + exporters)
Symptoms:
- `exceeded quota: payflow-quota` (pods/limits CPU/memory)
- `minimum cpu usage per Container is 50m` / `minimum memory usage per Container is 64Mi`
Causes:
- Namespace ResourceQuota caps exceeded.
- LimitRange minimums higher than the pod requests.
Checks:
- `kubectl -n payflow get resourcequota`
- `kubectl -n payflow describe resourcequota payflow-quota`
- `kubectl -n payflow get limitrange`
Fix:
- Increase `k8s/policies/resource-quotas.yaml` or scale workloads down.
- Lower LimitRange minimums in `k8s/policies/limit-range.yaml` or raise the pod requests.

### 4) CronJob pod pile-ups (transaction-timeout-handler)
Symptoms:
- Jobs keep creating pods until the pod quota is hit.
Causes:
- High schedule frequency and long job history retention.
Fix:
- Tune history + TTL in `k8s/jobs/transaction-timeout-handler.yaml`:
  - `successfulJobsHistoryLimit`, `failedJobsHistoryLimit`, `ttlSecondsAfterFinished`
  - `concurrencyPolicy: Forbid` to prevent overlap
- Optional cleanup:
  - `kubectl -n payflow delete job -l cronjob-name=transaction-timeout-handler`

### 5) Prometheus targets DOWN (auth/api-gateway/exporters)
Symptoms:
- `context deadline exceeded` or `404 Not Found` on `/metrics`
Causes:
- Service annotation points to the wrong port.
- App does not expose `/metrics`.
- NetworkPolicy blocks monitoring namespace.
Checks:
- `kubectl -n payflow get svc auth-service api-gateway -o wide`
- `kubectl -n payflow get endpoints auth-service api-gateway -o wide`
- `kubectl -n payflow get networkpolicy allow-monitoring-scrape`
Fix:
- api-gateway should scrape `port: 3000`, `path: /metrics` in `k8s/services/all-services.yaml`.
- auth-service does not expose `/metrics` in code; remove annotations or add metrics.
- Ensure `allow-monitoring-scrape` policy is applied.

### 6) Postgres exporter DB timeout
Symptoms:
- `Error opening connection to database` / `dial tcp ...:5432: connect: connection timed out`
Causes:
- Postgres exporter cannot reach the Postgres Service due to NetworkPolicy.
- Wrong DB host in exporter values.
Checks:
- `kubectl -n payflow get endpoints postgres-service -o wide`
- `kubectl -n payflow get networkpolicy postgres-ingress-from-services`
Fix:
- Allow `app.kubernetes.io/name=prometheus-postgres-exporter` in
  `k8s/policies/network-policies.yaml` (postgres ingress).
- Confirm `k8s/helm-values/monitoring/postgres-exporter-values.yaml`
  points to `postgres-service.payflow.svc.cluster.local:5432`.

## Helpful commands

- Check pods/services/ingress:
  - `kubectl -n payflow get pods,svc,ingress`
- Describe a service:
  - `kubectl -n payflow describe svc <service>`
- Check logs:
  - `kubectl -n payflow logs deploy/<deployment>`
- Check a pod environment:
  - `kubectl -n payflow exec -it <pod> -- env`

## Monitoring troubleshooting (Prometheus, Grafana, Loki)

Use this section when you see "DOWN" targets in Prometheus or no data in Grafana.

### 1) Grafana UI not reachable

Symptoms:
- Browser shows "connection refused" on EC2 public IP.

Cause:
- `kubectl port-forward` binds to localhost on the EC2 host.

Fix (SSH tunnel + port-forward):
- On your laptop:
  - `ssh -i /path/to/key.pem -L 3000:127.0.0.1:3000 ubuntu@<ec2-host>`
- On EC2:
  - `kubectl -n monitoring port-forward svc/payflow-grafana 3000:80`
- Open `http://localhost:3000` on your laptop.

### 2) Grafana has no metrics/logs

Checks:
- Data sources:
  - Grafana -> Connections -> Data sources -> Prometheus and Loki should be present.
- Prometheus targets:
  - `kubectl -n monitoring port-forward svc/payflow-prometheus-server 9090:80`
  - Open `http://localhost:9090/targets` and confirm payflow services are UP.
- Loki logs:
  - Grafana -> Explore -> Loki -> query `{namespace="payflow"}`.

### 3) Prometheus target timeouts (context deadline exceeded)

Cause:
- Default-deny NetworkPolicy in `payflow` blocks scrapes from `monitoring`.

Fix:
- Apply the monitoring scrape policy:
  - `kubectl apply -f k8s/policies/network-policies.yaml`
- Verify the policy exists:
  - `kubectl -n payflow get networkpolicy allow-monitoring-scrape`

### 4) Promtail cannot push logs (connection refused)

Symptoms:
- Promtail logs show `connect: connection refused` to Loki.

Causes:
- Loki not ready yet or has invalid config.

Fix:
- Check Loki pod:
  - `kubectl -n monitoring get pods | rg loki`
  - `kubectl -n monitoring logs payflow-loki-0 --tail=200`
- Ensure Loki uses single-binary + filesystem storage and has a schema:
  - `k8s/helm-values/monitoring/loki-values.yaml`

### 5) Loki CrashLoopBackOff

Common causes:
- Missing schema config or structured metadata mismatch.

Fixes:
- Ensure `schemaConfig` exists and `allow_structured_metadata: false`.
- Disable caches for small clusters to avoid memcached dependencies.

### 6) Exporters failing / no infra metrics

Checks:
- Exporter pods running:
  - `kubectl -n payflow get pods | rg exporter`
- Credentials come from `payflow-secrets`:
  - `DB_USER`, `DB_PASSWORD`, `REDIS_PASSWORD`, `RABBITMQ_DEFAULT_USER`, `RABBITMQ_DEFAULT_PASS`

Fix:
- Update `k8s/secrets/db-secrets.yaml` or set secrets in cluster, then rerun `deploy.sh`.

### 7) ResourceQuota blocks monitoring components

Symptoms:
- Errors like `exceeded quota: secrets` or `limits.cpu`.

Fix:
- Increase quotas in `k8s/policies/resource-quotas.yaml` and re-apply:
  - `kubectl apply -f k8s/policies/resource-quotas.yaml`

### 8) Quick in-cluster metrics check (without kubectl run limits)

Some kubectl versions do not support `--limits` on `kubectl run`.
Use overrides to avoid quota errors:

```
kubectl -n payflow run curltmp --rm -it --image=curlimages/curl \
  --overrides='{"apiVersion":"v1","spec":{"containers":[{"name":"curltmp","image":"curlimages/curl","resources":{"requests":{"cpu":"10m","memory":"32Mi"},"limits":{"cpu":"50m","memory":"64Mi"}},"command":["sh","-c","curl -s http://api-gateway:80/metrics | head"]}],"restartPolicy":"Never"}}'
```
