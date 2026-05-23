# payflow-wallet-k8s

PayFlow Wallet on AWS EKS, with Terraform for infrastructure, GitHub Actions for CI/CD, and GitOps for Kubernetes delivery.

## What this repo contains

- Terraform for AWS foundation, platform infrastructure, add-ons, and commented future edge config.
- GitHub Actions workflows for plans, applies, image builds, drift checks, and sync jobs.
- GitOps overlays and ingress values that Argo CD can reconcile into the cluster.
- A small set of local helper scripts for bootstrap and teardown only.

## Current local helpers

- `scripts/deploy-dev.sh`
  - manual bootstrap helper for dev
  - applies foundation and platform/infra locally when you need a starting point
- `scripts/teardown-dev.sh`
  - local teardown helper for dev
  - destroys the stack in dependency order

Legacy imperative deploy helpers have been archived under:

- `archive/legacy-scripts/`

## Recommended docs

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
  - current environment topology and layer ownership
- [docs/GITOPS.md](docs/GITOPS.md)
  - CI/CD, GitOps, Argo CD, and workflow conventions

## Day-to-day workflow

1. Use GitHub Actions for plans, applies, builds, and drift checks.
2. Let GitOps reconcile Kubernetes changes from Git.
3. Use `scripts/deploy-dev.sh` only when you need a manual dev bootstrap.
4. Use `scripts/teardown-dev.sh` when you want to clean up dev.

## Notes

- The old MicroK8s-era deployment guide is no longer the active path for this repo.
- Imperative full-stack deploy scripts are kept only as archived references.
- Secrets are handled through AWS/GitHub workflows and GitOps values, not by committing them into manifests.
