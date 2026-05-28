# GitOps and CI/CD (Argo CD + GitHub Actions)

This repo supports a split deployment model:

- Terraform manages AWS infrastructure (VPC/TGW/EKS/RDS/Redis/MQ) plus commented future Route 53/CloudFront/WAF edge config.
- Kubernetes manifests (workloads and ingress) are deployed from Git using GitOps.

The only local helper scripts that remain active are:

- `scripts/deploy-dev.sh`
- `scripts/teardown-dev.sh`

Older imperative deploy helpers are archived in:

- `archive/legacy-scripts/`

The EKS API is private-only in `dev`, so CI runners typically cannot `kubectl apply` directly. Argo CD solves this by running *inside* the cluster and pulling desired state from Git.

## Argo CD Scope (Recommended)

Recommended scope for Argo CD in this project:

- Manage **application workloads** from `overlays/<env>/` (Kustomize).
- Optionally manage in-cluster platform components (metrics, dashboards, etc.) if you move them out of Terraform/Helm providers.

Keep Terraform for:

- EKS, networking, IAM, RDS, ElastiCache, MQ, and any future edge/Route 53 restore work.

## Bootstrap Argo CD

Install Argo CD (one-time per cluster). Run from the bastion:

```bash
kubectl create namespace argocd || true
kubectl apply -n argocd -f k8s/argocd/install.yaml
```

Then apply the app of apps:

```bash
kubectl apply -n argocd -f k8s/argocd/apps/app-of-apps.yaml
```

## App Structure

- `k8s/argocd/apps/app-of-apps.yaml`: root app that points at the apps folder
- `k8s/argocd/apps/payflow-dev.yaml`: syncs `overlays/dev` as the dev example

## GitHub Actions (Terraform)

Use GitHub Actions for Terraform:

- `plan` on pull requests
- `apply` via `workflow_dispatch` (manual) or gated environments

Because EKS is private, do not run `kubectl` from Actions; Argo CD handles Kubernetes sync.

If you still want GitHub Actions to trigger a deployment to the cluster, this repo supports running `kubectl apply -k overlays/<env>` via SSM on the bastion (same pattern as `platform/addons`).

The main deployment workflow is environment-driven:

- `terraform-cicd.yml` accepts an `env` input such as `dev`, `staging`, or `prod`
- jobs use GitHub environments named `<env>-foundation-plan`, `<env>-foundation-apply`, `<env>-platform-plan`, `<env>-platform-apply`, `<env>-platform-verify`, `<env>-addons-plan`, `<env>-addons-apply`, `<env>-addons-verify`, and `<env>-overlays-apply`
- put the layer-specific AWS role in `AWS_ROLE_TO_ASSUME` for each GitHub environment
- put shared values such as `CLUSTER_NAME` and `BASTION_REPO_DIR` in GitHub environment variables; `APP_DOMAIN` is only needed again if you re-enable edge/Route 53

Recommended security split:

- `*-plan` environments: least-privileged read-only Terraform plan roles
- `*-apply` environments: restricted apply roles with approvals enabled
- `*-verify` environments: read-only validation roles for health checks and SSM discovery

The workflow auto-discovers the bastion instance id by querying EC2 instances with a `Name` tag matching `*-<env>-bastion`. It expects exactly one running bastion for the target environment, so ensure your bastion is tagged accordingly and the GitHub OIDC role has `ec2:DescribeInstances`.

### Required GitHub Secrets

- `AWS_ROLE_TO_ASSUME`: IAM role ARN for GitHub OIDC to assume (scoped to the Terraform layer(s) you allow).

Optional:

- `BASTION_REPO_DIR`: path to the repo checkout on the bastion (default: `/home/ssm-user/k8s-payflow`).

For ingress-value sync specifically, create a `dev-sync-ingress` GitHub environment and set:

- `AWS_ROLE_TO_ASSUME`: IAM role ARN for `payflow-dev-sync-ingress`

### Sync Terraform Outputs -> Ingress Values (PR Workflow)

To keep ingress values GitOps-native while still sourcing ARNs/domains from Terraform, use the workflow:

- `.github/workflows/sync-ingress-values.yml`

It reads `terraform output -json` from `terraform/environments/<env>/platform/infra` and opens a PR updating:

- `charts/payflow-ingress/values-<env>.yaml`

Argo CD then reconciles the ingress change from Git. In the current direct-ALB mode, the workflow leaves domain and certificate values alone and only updates the pieces that still matter for ingress.

Recommended sequence when ingress-related values may change:

1. Apply `terraform/environments/<env>/platform/infra`
2. Apply `terraform/environments/<env>/platform/addons`
3. Apply `kubectl apply -k overlays/<env>` so the ALB ingress exists
4. Leave `terraform/environments/<env>/edge` disabled unless you later regain a domain and want CloudFront/Route 53 back

### Drift Detection

This repo includes two scheduled drift checks:

- `.github/workflows/terraform-drift.yml`: runs `terraform plan -detailed-exitcode` for AWS-only layers (foundation/platform/infra).
- `.github/workflows/addons-drift-ssm.yml`: runs `terraform plan -detailed-exitcode` for `platform/addons` via SSM on the bastion (private EKS API).

Ensure the GitHub OIDC role has `ec2:DescribeInstances` (to discover bastion), plus `ssm:SendCommand`, `ssm:GetCommandInvocation`, and `ssm:ListCommandInvocations`.

## GitHub Actions (Payflow Wallet App)

The wallet app now has two dedicated workflows under `.github/workflows/`:

- `ci.yml`
  - runs lint, tests, dependency audits, secret scanning, and filesystem scanning
  - triggers on pull requests and pushes that touch `payflow-wallet/**`
- `build.yml`
  - builds each service Docker image
  - scans the image with Trivy before publishing
  - pushes SHA-tagged images to ECR for traceability
  - syncs `overlays/<env>/kustomization.yaml` image tags to the same SHA and opens a PR so Argo CD can roll the deployment

The images are tagged with the full commit SHA. That gives you a clean trace from source commit to container image in ECR.

The overlay sync currently targets `dev` on `test` pushes and `prod` on `main` pushes. You can also choose the target overlay manually when running `build.yml` via `workflow_dispatch`. The workflow now opens a PR instead of pushing directly to the branch, which plays nicer with branch protection.

For `build.yml`, create a GitHub Environment named `build` and store the ECR push role in `AWS_ROLE_TO_ASSUME` there. If you want the overlay sync PR branch to push through GitHub's workflow-file restrictions cleanly, also add a `WORKFLOW_PUSH_TOKEN` secret with workflow-write permission. That keeps the image publishing permissions separate from the environment-specific Terraform layers.

## Local Secret Scanning Hooks

This repo also includes local hooks so secrets are caught before they leave your machine:

- `gitleaks` runs on `pre-commit` and blocks obvious credential leaks in the working tree.

Install them with:

```bash
pre-commit install --hook-type pre-commit
```

Then install the tool itself:

- `gitleaks`

This keeps the local setup Windows-friendly and avoids the Go dependency that `trufflehog` needs.

## Notes

- GitOps-native ingress:
  - The ALB ingress is managed as Kubernetes source of truth in the repo.
  - Environment-specific values live in git (for example `charts/payflow-ingress/values-dev.yaml`).
  - Terraform no longer generates `overlays/<env>/alb-ingress.yaml` at deploy time.
- Imperative full-stack deploy scripts are intentionally archived so the active path stays CI + GitOps + the two local lifecycle helpers.
