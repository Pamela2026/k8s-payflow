# PayFlow Operations Runbook

> Environment: `payflow-dev`
> Cluster: `payflow-eks-dev`
> Region: `us-east-1`

## Access

### Connect to the Bastion

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*-bastion" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text
```

```bash
INSTANCE_ID=<bastion-instance-id>
aws ssm start-session --target "$INSTANCE_ID" --region us-east-1
```

Use Session Manager as the standard operator path. Do not rely on SSH for normal operations.

### Configure kubectl from the Bastion

```bash
cd /home/ssm-user/k8s-payflow
bash terraform/environments/dev/platform/infra/scripts/kcfg.sh
kubectl get nodes
```

Dev uses a private-only EKS endpoint, so local-machine `kubectl` access is not the standard path.

## Deploy

### Full Redeploy

Notes:

- Run AWS-only Terraform layers from your local machine.
- Run `platform/addons` and all `kubectl` / workload deploy steps from the bastion (private EKS API).
- Apply `edge` last (it depends on the ingress-created ALB existing).

```bash
cd terraform/environments/dev/foundation
terraform apply -var-file=terraform.tfvars

cd terraform/environments/dev/platform/infra
terraform apply -var-file=terraform.tfvars
```

Then from the bastion:

```bash
cd /home/ssm-user/k8s-payflow
git pull

cd ../platform/addons
terraform apply -var-file=terraform.tfvars

cd /home/ssm-user/k8s-payflow
bash k8s/scripts/render-eks-overlay.sh \
  --dns-dir terraform/environments/dev/platform/infra
bash scripts/deploy-eks-apps.sh
```

Finally, back on your local machine:

```bash
cd terraform/environments/dev/edge
terraform apply -var-file=terraform.tfvars
```

### Restart a Service

```bash
kubectl rollout restart deployment/auth -n payflow
kubectl rollout status deployment/auth -n payflow
```

### Roll Back a Service

```bash
kubectl rollout history deployment/auth -n payflow
kubectl rollout undo deployment/auth -n payflow
```

## Health Checks

### Cluster and Workloads

```bash
kubectl get nodes
kubectl top nodes
kubectl get pods -n payflow -o wide
kubectl get svc -n payflow
kubectl get ingress -n payflow
kubectl get externalsecrets -n payflow
```

### External Health

```bash
curl -I https://computehub.online/health
```

### ALB Hostname

```bash
kubectl get ingress payflow-alb -n payflow \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

The preferred public health check is the application domain, not the raw ALB hostname.

## Logs

### Application Logs

```bash
kubectl logs -l app=auth -n payflow --tail=100
kubectl logs <pod-name> -n payflow --tail=100
kubectl logs -f <pod-name> -n payflow
```

### Controller Logs

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### Node-Level Logs

```bash
aws ssm start-session --target <node-instance-id> --region us-east-1
journalctl -u kubelet -n 100
```

## Troubleshooting

### Pod Not Starting

```bash
kubectl describe pod <pod-name> -n payflow
kubectl logs <pod-name> -n payflow
```

### External Secrets Not Syncing

```bash
kubectl get externalsecrets -n payflow
kubectl describe externalsecret <name> -n payflow
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### ALB Not Creating or Updating

```bash
kubectl describe ingress payflow-alb -n payflow
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
aws elbv2 describe-load-balancers --region us-east-1
```

### Node Not Ready

```bash
kubectl describe node <node-name>
kubectl get events --field-selector involvedObject.name=<node-name>
```

### Bastion Cannot Reach Private EKS API

Symptom:

```text
Unable to connect to the server: dial tcp 10.1.120.66:443: i/o timeout
```

What we checked:

- The EKS control plane security group allowed TCP 443 from the bastion VPC CIDR.
- The bastion subnet route table already had a TGW route to the spoke VPC CIDR.
- The bastion subnet NACL was open in both directions.
- The private EKS API ENIs were in spoke data-private subnets.
- Those spoke subnet route tables had `local` and `nat` routes, but no TGW return route back to the hub VPC.

Root cause:

- The spoke data-private route tables were missing a return route to `10.0.0.0/16` via the Transit Gateway.

Fix:

- Add a TGW return route for the multi-AZ spoke private route tables in `terraform/modules/vpc/main.tf`.

Reference:

- [Incident 2026-05-28 - Private EKS API Reachability Failure](incident-2026-05-28-private-eks-reachability.md)

### Edge Routing or TLS Issues

```bash
kubectl get ingress payflow-alb -n payflow
curl -I https://computehub.online/health
```

If CloudFront or ALB behavior looks wrong, confirm:

- the ALB ingress certificate is present
- the WAF annotation is present
- the edge Terraform layer has been applied

If managed-service connectivity looks wrong in `dev`, confirm:

- `payflow-secrets` contains `DB_HOST`, `DB_PORT`, `DB_NAME`, `REDIS_URL`, and `RABBITMQ_ENDPOINT`
- `ExternalSecret/payflow-secrets` is healthy
- `overlays/dev/aws-managed-services-patch.yaml` is included in the applied overlay

## Tear Down

Destroy in reverse order. Delete the Kubernetes application workloads first so the ALB controller can clean up ingress-backed AWS resources before the supporting Terraform layers are removed.

### Delete Kubernetes Resources

```bash
kubectl delete -k /home/ssm-user/k8s-payflow/overlays/dev
```

### Destroy Terraform

Notes:

- Delete Kubernetes resources from the bastion first.
- Destroy `platform/addons` from the bastion (Kubernetes/Helm providers).
- Destroy AWS-only layers (edge, platform/infra, foundation) from your local machine.

```bash
cd terraform/environments/dev/edge
terraform destroy -var-file=terraform.tfvars

cd ../platform/infra
terraform destroy -var-file=terraform.tfvars

cd ../../foundation
terraform destroy -var-file=terraform.tfvars
```

### Destroy Bootstrap

```bash
cd /home/ssm-user/k8s-payflow/terraform/bootstrap
terraform destroy -var-file=terraform.tfvars
```

## Quick Reference

```bash
aws ssm start-session --target <bastion-instance-id> --region us-east-1
kubectl port-forward svc/auth 8080:80 -n payflow
kubectl exec -it <pod-name> -n payflow -- /bin/sh
kubectl scale deployment/auth --replicas=3 -n payflow
kubectl top pods -n payflow
```
