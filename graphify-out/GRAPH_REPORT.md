# Graph Report - HomeLab  (2026-06-06)

## Corpus Check
- 22 files · ~16,135 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 156 nodes · 163 edges · 27 communities (8 shown, 19 thin omitted)
- Extraction: 91% EXTRACTED · 8% INFERRED · 1% AMBIGUOUS · INFERRED: 13 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `3def92a0`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]

## God Nodes (most connected - your core abstractions)
1. `RKE2 Homelab Kubernetes Cluster` - 19 edges
2. `Fixes Applied to RKE2 HomeLab Ansible` - 11 edges
3. `DNS Resolver Update Playbook` - 9 edges
4. `Ansible Collections Requirements` - 9 edges
5. `Traefik Ingress Role Tasks` - 9 edges
6. `Installation Steps` - 8 edges
7. `Global Cluster Variables` - 8 edges
8. `Playbook 03: Install Add-ons` - 8 edges
9. `Fixes Applied` - 7 edges
10. `Fixes Applied Documentation` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Pre-commit Config Hooks` --references--> `RKE2 Homelab README`  [AMBIGUOUS]
  .pre-commit-config.yaml → rke2-homelab-ansible/README.md
- `Global Cluster Variables` --shares_data_with--> `Cilium Role Defaults`  [INFERRED]
  rke2-homelab-ansible/group_vars/all.yml → rke2-homelab-ansible/roles/cilium/defaults/main.yml
- `Fixes Applied Documentation` --cites--> `Fix Cert-Manager Playbook`  [EXTRACTED]
  rke2-homelab-ansible/FIXES-APPLIED.md → rke2-homelab-ansible/fix-cert-manager.yml
- `Global Cluster Variables` --shares_data_with--> `RKE2 Master Role Defaults`  [INFERRED]
  rke2-homelab-ansible/group_vars/all.yml → rke2-homelab-ansible/roles/rke2-master/defaults/main.yml
- `Global Cluster Variables` --shares_data_with--> `RKE2 Worker Role Defaults`  [INFERRED]
  rke2-homelab-ansible/group_vars/all.yml → rke2-homelab-ansible/roles/rke2-worker/defaults/main.yml

## Import Cycles
- None detected.

## Communities (27 total, 19 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.15
Nodes (21): Longhorn Distributed Storage, Traefik Ingress Controller, Fix Cert-Manager Playbook, Inventory Hosts Configuration, Playbook 01: Prepare Nodes, Playbook 02: Install RKE2, Playbook 03: Install Add-ons, Pre-commit Config Hooks (+13 more)

### Community 1 - "Community 1"
Cohesion: 0.10
Nodes (20): Access Your Cluster, Architecture, Backup etcd, Components, Configuration, Documentation, Installation, Learning Resources (+12 more)

### Community 2 - "Community 2"
Cohesion: 0.11
Nodes (18): 1. Worker Configuration ✅, 2. CoreDNS Deployment ✅, 3. Environment Variable Validation ✅, 4. Python Dependencies ✅, 5. API Endpoint Configuration ✅, 6. Cloudflare Secret Distribution for cert-manager ✅, Architecture Notes, Certificate Issuance Failures (+10 more)

### Community 3 - "Community 3"
Cohesion: 0.25
Nodes (11): cert-manager TLS Management, Cloudflare DNS Integration, Let's Encrypt ACME, RKE2 Kubernetes Cluster, Global Cluster Variables, RKE2 Masters Group Variables, RKE2 Workers Group Variables, RKE2 Master Role Defaults (+3 more)

### Community 4 - "Community 4"
Cohesion: 0.29
Nodes (10): Cilium CNI, CoreDNS Cluster DNS, Deploy CoreDNS Playbook, Fixes Applied Documentation, Cilium Role Defaults, Cilium Role Tasks, RKE2 Worker Role Defaults, RKE2 Worker Role Handlers (+2 more)

### Community 18 - "Community 18"
Cohesion: 0.12
Nodes (15): Check What Would Change (Dry Run), Customization, DNS Resolver Update Playbook, Files, For Proxmox LXC/VM Creation, For Proxmox Templates, Notes, Option 1: Update to Static Gateway DNS (10.20.10.1) (+7 more)

### Community 19 - "Community 19"
Cohesion: 0.18
Nodes (10): 1. Prepare VMs, 2. Setup Control Machine, 3. Set Environment Variables, 4. Test Connectivity, 5. Run Playbooks, 6. Configure External Traefik, 7. Access Cluster, Common Commands (+2 more)

### Community 20 - "Community 20"
Cohesion: 0.40
Nodes (5): Cilium Issues, Nodes Not Ready, Pods Not Starting, Storage Problems, Troubleshooting

## Ambiguous Edges - Review These
- `Pre-commit Config Hooks` → `RKE2 Homelab README`  [AMBIGUOUS]
  .pre-commit-config.yaml · relation: references

## Knowledge Gaps
- **87 isolated node(s):** `PreToolUse`, `allow`, `PreToolUse`, `BeforeTool`, `COMPLETE-SETUP.sh script` (+82 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **19 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Pre-commit Config Hooks` and `RKE2 Homelab README`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `RKE2 Homelab Kubernetes Cluster` connect `Community 1` to `Community 20`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Why does `Ansible Collections Requirements` connect `Community 0` to `Community 4`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Why does `Traefik Ingress Role Tasks` connect `Community 0` to `Community 3`, `Community 4`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **What connects `PreToolUse`, `allow`, `PreToolUse` to the rest of the system?**
  _87 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.09523809523809523 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._