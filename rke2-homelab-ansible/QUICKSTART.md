# Quick Start Guide

## Installation Steps

### 1. Prepare VMs

On each of the 6 VMs:
```bash
# Create ansible user
sudo useradd -m -s /bin/bash ansible
sudo usermod -aG sudo ansible
sudo bash -c 'echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible'

# Add SSH key
sudo mkdir -p /home/ansible/.ssh
sudo bash -c 'echo "YOUR_SSH_PUBLIC_KEY" >> /home/ansible/.ssh/authorized_keys'
sudo chown -R ansible:ansible /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh
sudo chmod 600 /home/ansible/.ssh/authorized_keys
```

Add 100GB disk to each VM in Proxmox.

### 2. Setup Control Machine

```bash
pip install ansible
cd rke2-homelab-ansible
ansible-galaxy collection install -r requirements.yml
```

### 3. Set Environment Variables

```bash
export CLOUDFLARE_API_TOKEN="your_cloudflare_token"
export ACME_EMAIL="your-email@example.com"
```

### 4. Test Connectivity

```bash
ansible -i inventory/hosts.yml all -m ping
```

### 5. Run Playbooks

```bash
# Phase 1: Prepare nodes (~15 min)
ansible-playbook -i inventory/hosts.yml playbooks/01-prepare-nodes.yml

# Phase 2: Install RKE2 (~20 min)
ansible-playbook -i inventory/hosts.yml playbooks/02-install-rke2.yml

# Phase 3: Install add-ons (~15 min)
ansible-playbook -i inventory/hosts.yml playbooks/03-install-addons.yml
```

### 6. Configure External Traefik

Forward traffic:
- `kube01-api.tanx95.us:6443` → masters:6443
- `*.kube01.tanx95.us:80` → workers:30080
- `*.kube01.tanx95.us:443` → workers:30443

### 7. Access Cluster

```bash
export KUBECONFIG=~/.kube/kube01-config
kubectl get nodes
```

Access services:
- https://longhorn.kube01.tanx95.us
- https://nginx.kube01.tanx95.us

## Common Commands

```bash
# Cluster status
kubectl get nodes
kubectl get pods -A

# Cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium status

# Storage
kubectl get pv,pvc -A

# Logs
kubectl logs -n <namespace> <pod>
```

Done! 🎉
