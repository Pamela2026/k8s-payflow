# payflow-wallet-k8s

End-to-end deployment guide for running PayFlow on MicroK8s.

## Prerequisites

- MicroK8s installed and running.
- `kubectl` configured to point at MicroK8s (`microk8s kubectl` also works).

## 1) Enable required addons

```bash
microk8s enable dns storage ingress
```

Optional (only if you want a LoadBalancer service instead of Ingress):

```bash
microk8s enable metallb
```

## 2) Create the namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

## 3) Create secrets (required)

The repo ships a template at `k8s/secrets/db-secrets.yaml`. You must create real secrets or pods will fail.

Create the secret directly:

```bash
kubectl create secret generic payflow-secrets -n payflow \
  --from-literal=DB_USER=payflow \
  --from-literal=DB_PASSWORD=payflow123 \
  --from-literal=JWT_SECRET=your-jwt-secret \
  --from-literal=RABBITMQ_DEFAULT_USER=payflow \
  --from-literal=RABBITMQ_DEFAULT_PASS=payflow123 \
  --dry-run=client -o yaml | kubectl apply -f -
```

If you prefer to apply a manifest, update `k8s/secrets/db-secrets.yaml` with base64 values and apply it:

```bash
kubectl apply -f k8s/secrets/db-secrets.yaml
```

## 4) (Optional) Create TLS secret for Ingress

If you plan to use the TLS ingress (`k8s/ingress/tls-ingress-payflow.yaml`), you must create `payflow-tls`:

```bash
kubectl create secret tls payflow-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n payflow
```

If you do not have TLS certs, skip the TLS ingress and apply only the HTTP ingress.

## 5) Apply configmaps

```bash
kubectl apply -f k8s/configmaps/app-config.yaml
kubectl apply -f k8s/configmaps/db-migrations.yaml
```

## 6) Deploy infrastructure services

```bash
kubectl apply -f k8s/infrastructure/postgres.yaml
kubectl apply -f k8s/infrastructure/redis.yaml
kubectl apply -f k8s/infrastructure/rabbitmq.yaml
```

Wait for them to become ready before continuing:

```bash
kubectl -n payflow get pods
```

## 7) Run database migrations

```bash
kubectl apply -f k8s/jobs/db-migration-job.yaml
```

Check job status:

```bash
kubectl -n payflow get jobs
```

## 8) Deploy application services

```bash
kubectl apply -f k8s/deployments/auth-service.yaml
kubectl apply -f k8s/deployments/wallet-service.yaml
kubectl apply -f k8s/deployments/transaction-service.yaml
kubectl apply -f k8s/deployments/notification-service.yaml
kubectl apply -f k8s/deployments/api-gateway.yaml
kubectl apply -f k8s/deployments/frontend.yaml
```

## 9) Apply services and ingress

```bash
kubectl apply -f k8s/services/all-services.yaml
```

Choose one ingress option:

- HTTP only:

```bash
kubectl apply -f k8s/ingress/http-ingress.yaml
```

- TLS (requires `payflow-tls` secret):

```bash
kubectl apply -f k8s/ingress/tls-ingress-payflow.yaml
```

## 10) Apply policies and autoscaling

```bash
kubectl apply -f k8s/policies/limit-range.yaml
kubectl apply -f k8s/policies/resource-quotas.yaml
kubectl apply -f k8s/policies/pod-disruption-budgets.yaml
kubectl apply -f k8s/policies/network-policies.yaml
kubectl apply -f k8s/autoscaling/hpa.yaml
```

## 11) Apply the CronJob

```bash
kubectl apply -f k8s/jobs/transaction-timeout-handler.yaml
```

## 12) Verify

```bash
kubectl -n payflow get pods,svc,ingress
```

If you use the HTTP ingress, you can access it two ways:

Option A: Use the ingress IP (works without DNS)

```bash
kubectl -n payflow get ingress
```

Then access:

- Frontend: `http://<INGRESS_IP>/`
- API Gateway: `http://<INGRESS_IP>/api`

Option B: Use local DNS entries for the hostnames:

```text
<ingress-ip> payflow.local
<ingress-ip> api.payflow.local
```

Then access:

- Frontend: `http://payflow.local`
- API Gateway: `http://api.payflow.local`

## AWS EC2 access notes

- Open inbound rules on the EC2 security group for ports 80 (HTTP) and 443 (HTTPS) from your client IP or CIDR.
- Use the EC2 public IP or public DNS name as `<INGRESS_IP>` in the URLs above if the ingress controller is exposed on the instance.
- If you prefer hostnames, point `payflow.local` and `api.payflow.local` at the EC2 public IP in your local `hosts` file.
- If your ingress controller service is `ClusterIP`, use port-forwarding. From a browser on your laptop, set up an SSH tunnel to the EC2 host:

```bash
ssh -L 8080:127.0.0.1:8080 ubuntu@<EC2_PUBLIC_IP>
```

Then on the EC2 host, run:

```bash
microk8s kubectl -n ingress get svc
microk8s kubectl -n ingress port-forward svc/<ingress-service-name> 8080:80
```

Then access locally:

- Frontend: `http://localhost:8080/`
- API Gateway: `http://localhost:8080/api`

## Notes

- If you need a LoadBalancer service for the frontend, change `k8s/services/all-services.yaml` back to `type: LoadBalancer` and enable the MicroK8s `metallb` addon.
- The default NetworkPolicies enforce a deny-all posture and only allow required traffic.
