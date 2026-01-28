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

## Helpful commands

- Check pods/services/ingress:
  - `kubectl -n payflow get pods,svc,ingress`
- Describe a service:
  - `kubectl -n payflow describe svc <service>`
- Check logs:
  - `kubectl -n payflow logs deploy/<deployment>`
- Check a pod environment:
  - `kubectl -n payflow exec -it <pod> -- env`
