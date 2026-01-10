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
