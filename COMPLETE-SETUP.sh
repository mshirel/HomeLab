#!/bin/bash
set -e

cat << "BANNER"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║       RKE2 Homelab Kubernetes Cluster Setup               ║
║       Complete Installation Script                        ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
BANNER

echo ""
echo "This script will create the complete RKE2 Ansible project structure"
echo "with all roles, playbooks, and documentation."
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Check if directory exists
if [ -d "rke2-homelab-ansible" ]; then
    echo "ERROR: Directory 'rke2-homelab-ansible' already exists!"
    echo "Please remove it first: rm -rf rke2-homelab-ansible"
    exit 1
fi

echo "[1/8] Creating base project structure..."
bash setup-rke2-ansible.sh

echo ""
echo "[2/8] Setting up RKE2 Master role..."
bash setup-role-rke2-master.sh

echo ""
echo "[3/8] Setting up RKE2 Worker role..."
bash setup-role-rke2-worker.sh

echo ""
echo "[4/8] Setting up Cilium role..."
bash setup-role-cilium.sh

echo ""
echo "[5/8] Setting up Longhorn role..."
bash setup-role-longhorn.sh

echo ""
echo "[6/8] Setting up Traefik Ingress role..."
bash setup-role-traefik-ingress.sh

echo ""
echo "[7/8] Setting up Test Apps role..."
bash setup-role-test-apps.sh

echo ""
echo "[8/8] Creating documentation files..."

cd rke2-homelab-ansible

# Add README note
cat > README.md << 'READMEOF'
# RKE2 Homelab Kubernetes Cluster

A complete Ansible automation project for deploying a production-ready RKE2 Kubernetes cluster on Ubuntu 24.04 VMs.

## Quick Start

See `QUICKSTART.md` for step-by-step installation instructions.

## Architecture

- **6-node HA cluster**: 3 control plane masters + 3 workers
- **Cilium CNI**: Modern eBPF-based networking with Hubble observability
- **Longhorn Storage**: Distributed block storage with 3-way replication
- **Traefik Ingress**: NodePort-based ingress with Let's Encrypt (DNS-01/Cloudflare)
- **Automated Certificates**: cert-manager for SSL/TLS management

## Components

- RKE2 (stable channel)
- Cilium 1.15.x
- Longhorn 1.6.x
- Traefik 26.x
- cert-manager 1.14.x

## Prerequisites

1. 6 Ubuntu 24.04 VMs on Proxmox
2. 100GB secondary disk (`/dev/sdb`) on each VM
3. Ansible user with SSH key access
4. DNS records configured
5. Cloudflare API token
6. External Traefik for load balancing

## Installation

```bash
# Install Ansible and dependencies
pip install ansible
ansible-galaxy collection install -r requirements.yml

# Set environment variables
export CLOUDFLARE_API_TOKEN="your-token"
export ACME_EMAIL="your-email@example.com"

# Run playbooks in order
ansible-playbook -i inventory/hosts.yml playbooks/01-prepare-nodes.yml
ansible-playbook -i inventory/hosts.yml playbooks/02-install-rke2.yml
ansible-playbook -i inventory/hosts.yml playbooks/03-install-addons.yml
```

## Post-Installation

Configure your external Traefik to forward:
- `kube01-api.tanx95.us:6443` → masters:6443 (Kubernetes API)
- `*.kube01.tanx95.us:80/443` → workers:30080/30443 (Ingress)

## Access Your Cluster

```bash
export KUBECONFIG=~/.kube/kube01-config
kubectl get nodes
```

Visit:
- Longhorn UI: https://longhorn.kube01.tanx95.us
- Test App: https://nginx.kube01.tanx95.us

## Configuration

All configurable values are in:
- `group_vars/all.yml` - Global settings
- `group_vars/rke2_masters.yml` - Master configuration
- `group_vars/rke2_workers.yml` - Worker configuration

## Documentation

- `QUICKSTART.md` - Step-by-step installation guide
- Role defaults in `roles/*/defaults/main.yml`
- Inline comments in tasks

## Network Configuration

- Pod CIDR: 10.42.0.0/16
- Service CIDR: 10.43.0.0/16
- Host Network: 10.20.x.x (DHCP)
- Ingress NodePorts: 30080 (HTTP), 30443 (HTTPS)

## Storage

- Device: `/dev/sdb` (100GB XFS)
- Mount: `/var/lib/longhorn`
- Replicas: 3 across workers
- Reclaim Policy: Retain

## Security

- Firewall enabled (UFW)
- Master nodes tainted (no workloads)
- IPv6 disabled system-wide
- Swap disabled
- Kernel hardening applied

## Troubleshooting

### Nodes Not Ready
```bash
# On the problematic node
sudo journalctl -u rke2-server -f  # masters
sudo journalctl -u rke2-agent -f   # workers
```

### Pods Not Starting
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl get events -n <namespace>
```

### Cilium Issues
```bash
kubectl -n kube-system exec -it ds/cilium -- cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium connectivity test
```

### Storage Problems
```bash
kubectl get pods -n longhorn-system
# Access UI: https://longhorn.kube01.tanx95.us
```

## Maintenance

### Backup etcd
```bash
# On any master
sudo rke2 etcd-snapshot save --name backup-$(date +%Y%m%d)
```

### Upgrade RKE2
Update `rke2_version` in `group_vars/all.yml` and re-run:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/02-install-rke2.yml
```

## Project Structure

```
rke2-homelab-ansible/
├── ansible.cfg
├── requirements.yml
├── inventory/hosts.yml
├── group_vars/
├── playbooks/
│   ├── 01-prepare-nodes.yml
│   ├── 02-install-rke2.yml
│   └── 03-install-addons.yml
└── roles/
    ├── common/
    ├── storage/
    ├── rke2-master/
    ├── rke2-worker/
    ├── cilium/
    ├── longhorn/
    ├── traefik-ingress/
    └── test-apps/
```

## Learning Resources

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [RKE2 Docs](https://docs.rke2.io/)
- [Cilium Docs](https://docs.cilium.io/)
- [Longhorn Docs](https://longhorn.io/docs/)

## License

MIT License - Free to use and modify

## Support

Open an issue on GitHub for bugs or questions.

---

**Built for learning, ready for production.** 🚀
READMEOF

# Create QUICKSTART.md
cat > QUICKSTART.md << 'QSEOF'
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
QSEOF

cd ..

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║              ✓ Setup Complete!                            ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Project created in: ./rke2-homelab-ansible/"
echo ""
echo "Next steps:"
echo "1. cd rke2-homelab-ansible"
echo "2. Review and customize group_vars/*.yml"
echo "3. Follow QUICKSTART.md for installation"
echo ""
echo "Happy clustering! 🚀"