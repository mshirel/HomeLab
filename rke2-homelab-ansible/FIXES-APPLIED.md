# Fixes Applied to RKE2 HomeLab Ansible

This document summarizes all the fixes that have been codified into the Ansible playbooks to ensure a clean cluster rebuild.

## Summary

All critical fixes have been integrated into the Ansible playbooks. You can now rebuild the cluster from scratch using the standard playbook sequence.

## Fixes Applied

### 1. Worker Configuration ✅

**Files Modified:**
- `roles/rke2-worker/templates/config-agent.yaml.j2`
- `roles/rke2-worker/defaults/main.yml`
- `group_vars/rke2_workers.yml`
- `group_vars/all.yml`

**Changes:**
- Workers connect directly to first master (`kube01-master01.tanx95.us:9345`) instead of load balancer for joining
- Added `rke2_supervisor_port` variable (9345) for agent registration
- Removed `node-role.kubernetes.io/worker=true` label (prevents workers from joining)
- Workers only have `storage-node=true` label

**Rationale:** RKE2 agents must connect to port 9345 (supervisor API) on a master node to join the cluster, not to the load balancer.

### 2. CoreDNS Deployment ✅

**Files Modified:**
- `roles/cilium/tasks/main.yml`

**Changes:**
- Added CoreDNS deployment tasks to the Cilium role
- Deploys CoreDNS ServiceAccount, ClusterRole, ClusterRoleBinding
- Creates CoreDNS ConfigMap with proper Corefile configuration
- Creates kube-dns Service at cluster IP `10.43.0.10` (from `cluster_dns` variable)
- Deploys CoreDNS Deployment with 2 replicas
- Waits for CoreDNS pods to be ready

**Rationale:** RKE2 was configured with `disable: - rke2-coredns`, so CoreDNS must be deployed manually. Without DNS, pod-to-pod communication fails.

### 3. Environment Variable Validation ✅

**Files Modified:**
- `playbooks/03-install-addons.yml`

**Changes:**
- Added pre-task checks for `CLOUDFLARE_API_TOKEN` and `ACME_EMAIL` environment variables
- Playbook fails immediately with clear error message if variables are not set
- Displays variable status when validation passes

**Rationale:** Prevents deploying cert-manager with empty credentials which causes certificate issuance failures.

### 4. Python Dependencies ✅

**Files Modified:**
- `playbooks/03-install-addons.yml`

**Changes:**
- Added pre-task to install `python3-kubernetes` and `python3-yaml` system packages
- Uses apt instead of pip to avoid PEP 668 externally-managed-environment issues on Ubuntu 24.04

**Rationale:** The `kubernetes.core` Ansible collection requires these Python libraries to manage Kubernetes resources.

### 5. API Endpoint Configuration ✅

**Files Modified:**
- `group_vars/all.yml`

**Changes:**
- Clarified `kube_api_port: 6443` is for Kubernetes API (kubectl)
- Added `rke2_supervisor_port: 9345` for RKE2 supervisor API (agent registration)
- Variables are used correctly in worker config templates

**Rationale:** Separates the two different ports used by RKE2 for clarity and proper configuration.

### 6. Cloudflare Secret Distribution for cert-manager ✅

**Files Modified:**
- `roles/traefik-ingress/templates/cluster-issuer.yaml.j2`
- `roles/traefik-ingress/tasks/main.yml`

**Changes:**
- Create Cloudflare API token secret in `cert-manager` namespace (primary location)
- Added task to copy the secret to all namespaces that request certificates (`longhorn-system`, `test-apps`)
- Removed unsupported `namespace` field from ClusterIssuer's `apiTokenSecretRef`

**Rationale:** When a Certificate resource requests a cert, cert-manager looks for the Cloudflare secret in the **same namespace as the Certificate**, not in a centralized location. ClusterIssuers don't support cross-namespace secret references in older cert-manager versions. The solution is to replicate the secret to each namespace that needs certificates.

## Environment Variables Required

Before running the addons playbook, export these variables:

```bash
export CLOUDFLARE_API_TOKEN="your_cloudflare_api_token"
export ACME_EMAIL="your-email@example.com"
```

These are mapped in `group_vars/all.yml`:
```yaml
cloudflare_api_token: "{{ lookup('env', 'CLOUDFLARE_API_TOKEN') }}"
acme_email: "{{ lookup('env', 'ACME_EMAIL') | default('admin@' + cluster_domain, true) }}"
```

**IMPORTANT:** When running the playbook with `--tags`, the `pre_tasks` section is skipped, which means environment variable validation is bypassed. To ensure proper deployment:

- **Correct:** Run without `--tags` or use `--skip-tags` to skip unwanted roles:
  ```bash
  ansible-playbook -i inventory/hosts.yml playbooks/03-install-addons.yml --skip-tags cilium,longhorn
  ```

- **Incorrect:** Using `--tags` skips pre_tasks and environment variable validation:
  ```bash
  # This will NOT pick up environment variables!
  ansible-playbook -i inventory/hosts.yml playbooks/03-install-addons.yml --tags traefik
  ```

## Playbook Execution Order

To build a clean cluster from scratch:

1. **Prepare nodes:**
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/01-prepare-nodes.yml
   ```

2. **Install RKE2:**
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/02-install-rke2.yml
   ```

3. **Install addons (with environment variables set):**
   ```bash
   export CLOUDFLARE_API_TOKEN="your_token"
   export ACME_EMAIL="your@email.com"
   ansible-playbook -i inventory/hosts.yml playbooks/03-install-addons.yml
   ```

## What Gets Deployed

The playbooks will now correctly deploy:

- ✅ 3 RKE2 master nodes (control-plane + etcd)
- ✅ 3 RKE2 worker nodes
- ✅ Cilium CNI (networking)
- ✅ CoreDNS (cluster DNS)
- ✅ Longhorn (persistent storage with CSI driver)
- ✅ Traefik (ingress controller with NodePort)
- ✅ cert-manager (TLS certificate management)
- ✅ Let's Encrypt ClusterIssuer (with Cloudflare DNS-01 challenge)

## Known Configuration

- **Cluster API endpoint:** `kube01-api.tanx95.us:6443` (load-balanced)
- **Worker registration:** Direct to `kube01-master01.tanx95.us:9345`
- **DNS Service IP:** `10.43.0.10`
- **Pod CIDR:** `10.42.0.0/16`
- **Service CIDR:** `10.43.0.0/16`
- **Ingress NodePorts:** HTTP=30080, HTTPS=30443

## Temporary Files (Can be Deleted)

These files were created for manual fixes and are no longer needed:

- `update-worker-config.yml` - Manual worker config update (functionality now in main playbooks)
- `fix-cert-manager.yml` - Manual cert-manager fix (functionality now in main playbooks)
- `deploy-coredns.yml` - Manual CoreDNS deployment (now in Cilium role)

You can safely delete these files as the fixes are integrated into the main playbooks.

## Verification Commands

After deployment, verify the cluster:

```bash
# Check all nodes are ready
kubectl get nodes

# Check all pods are running
kubectl get pods -A

# Verify DNS is working
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check Cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium status

# Verify storage class
kubectl get storageclass

# Check ClusterIssuer is ready
kubectl get clusterissuer

# View Traefik service
kubectl get svc -n traefik traefik
```

## Troubleshooting

If issues occur during deployment:

1. **Workers can't join:** Check they're connecting to master01:9345, not the load balancer
2. **DNS not working:** Verify CoreDNS pods are running in kube-system namespace
3. **PVCs pending:** Ensure Longhorn CSI driver is registered (`kubectl get csidriver`)
4. **Traefik pods pending:** Check if PVC is bound (`kubectl get pvc -n traefik`)
5. **Certificate errors:** Verify ClusterIssuer is Ready and has correct Cloudflare token

### Certificate Issuance Failures

If certificates remain in `READY: False` state and cert-manager logs show "secret not found" errors:

**Symptoms:**
```bash
$ kubectl get certificate -A
NAMESPACE         NAME                 READY   SECRET               AGE
longhorn-system   longhorn-tls         False   longhorn-tls         14h
test-apps         nginx-test-tls       False   nginx-test-tls       13h

$ kubectl describe challenge -n test-apps
...
Reason: error getting cloudflare secret: secrets "cloudflare-api-token-secret" not found
```

**Root Causes:**
1. The Cloudflare API token secret is empty because environment variables weren't set when the playbook ran
2. The `--tags` flag was used which skipped the pre_tasks section that validates environment variables
3. The Cloudflare secret wasn't copied to the namespace where the certificate is being requested

**Fix (via Ansible - preferred for clean rebuilds):**
```bash
# 1. Set environment variables
export CLOUDFLARE_API_TOKEN="your_actual_cloudflare_token"
export ACME_EMAIL="your-email@example.com"

# 2. Re-run the addon playbook WITHOUT using --tags (use --skip-tags instead)
ansible-playbook -i inventory/hosts.yml playbooks/03-install-addons.yml \
  --skip-tags cilium,longhorn \
  -e "ansible_python_interpreter=/usr/bin/python3"

# 3. Verify secrets exist in all necessary namespaces
for ns in cert-manager longhorn-system test-apps; do
  echo -n "$ns: "
  kubectl get secret cloudflare-api-token-secret -n $ns -o jsonpath='{.data.api-token}' 2>/dev/null | base64 -d | wc -c
done
# Each should show 40 (or the length of your token)

# 4. Delete stuck certificate requests to trigger retry
kubectl delete certificaterequest --all -n test-apps
kubectl delete certificaterequest --all -n longhorn-system

# 5. Monitor certificate issuance
watch kubectl get certificate -A
```

**Quick Fix (manual - for existing deployments):**
```bash
# Copy the secret from cert-manager to namespaces that need it
for ns in longhorn-system test-apps; do
  kubectl get secret cloudflare-api-token-secret -n cert-manager -o yaml | \
    sed "s/namespace: cert-manager/namespace: $ns/" | \
    kubectl apply -f -
done

# Delete stuck certificate requests
kubectl delete certificaterequest --all -A

# Monitor progress
watch kubectl get certificate -A
```

**Expected Timeline:**
- Certificates transition to `READY: True` within 2-5 minutes after DNS propagation
- You can monitor DNS-01 challenge progress with: `kubectl describe challenge -n <namespace>`
- Successful challenges will show: "Waiting for DNS-01 challenge propagation" → "Successfully authorized"

## Architecture Notes

- RKE2 has `rke2-coredns` disabled, CoreDNS is deployed by Ansible
- Workers connect directly to first master for initial join
- Load balancer (`kube01-api.tanx95.us`) is used for kubectl/API access only
- Cloudflare DNS-01 challenge is used for Let's Encrypt certificates
