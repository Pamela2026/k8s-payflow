# Incident Runbook - Private EKS API Reachability Failure
**Date:** 2026-05-28  
**Environment:** payflow-dev (AWS us-east-1)  
**Cluster:** payflow-eks-dev  
**Bastion:** payflow-dev-bastion

---

## Incident - Bastion Could Not Reach Private EKS API

### Error

```text
Unable to connect to the server: dial tcp 10.1.120.66:443: i/o timeout
```

The same timeout alternated between private endpoint IPs in the `10.1.110.0/24` and `10.1.120.0/24` ranges.

### Symptoms

- `aws eks update-kubeconfig` succeeded on the bastion.
- `kubectl` resolved the cluster endpoint successfully.
- `kubectl` timed out when connecting to the private EKS API IPs.
- The failure happened during the bastion-run `kcfg.sh` / `kubectl` steps in the addons apply path.

### How We Found It

We walked the network path from the bastion to the EKS control plane, step by step:

1. Confirmed the EKS cluster security group allowed inbound TCP 443 from the bastion VPC CIDR `10.0.0.0/16`.
2. Confirmed the bastion subnet route table had a route to the TGW for `10.1.0.0/16`.
3. Confirmed the bastion subnet NACL was open in both directions.
4. Identified the private EKS API ENIs with:

```bash
aws ec2 describe-network-interfaces \
  --region us-east-1 \
  --filters \
    "Name=addresses.private-ip-address,Values=10.1.110.99,10.1.120.66" \
  --query 'NetworkInterfaces[].{NetworkInterfaceId:NetworkInterfaceId,SubnetId:SubnetId,Description:Description,Groups:Groups[*].GroupId,PrivateIp:PrivateIpAddress}' \
  --output table
```

5. Found those ENIs lived in the spoke data-private subnets:
   - `subnet-0a0eb91c2a14ecd9d`
   - `subnet-02077bd2e4d0975bd`
6. Checked the route tables for those subnets and found they had:
   - `10.1.0.0/16 -> local`
   - `0.0.0.0/0 -> nat`
   - but **no return route to the hub VPC via TGW**

### Root Cause

The multi-AZ spoke data-private route tables did not have a return route back to the hub VPC (`10.0.0.0/16`) via the Transit Gateway.

That meant:
- the bastion could send traffic toward the EKS private API
- but the response path from the endpoint subnets back to the bastion VPC was incomplete
- `kubectl` hung until it timed out at the TCP layer

### Fix

Added a TGW return route for the multi-AZ spoke private route tables in `terraform/modules/vpc/main.tf`:

- destination: `var.hub_vpc_cidr`
- target: `aws_ec2_transit_gateway.core[0].id`
- applied to the AZ-specific spoke private route tables used by the data-private subnets

### Verification

After the route exists, the spoke data-private subnet route tables should include:

- `10.0.0.0/16 -> tgw-...`

Then the bastion-run `kcfg.sh` / `kubectl` flow should be able to reach the private EKS API without TCP timeouts.

### Notes

- This was not a kubeconfig problem.
- This was not a Security Group problem.
- This was not a NACL problem.
- This was a missing TGW return route on the spoke data-private side.

