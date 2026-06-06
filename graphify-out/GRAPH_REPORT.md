# Graph Report - .  (2026-06-06)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 60 nodes · 77 edges · 18 communities (14 shown, 4 thin omitted)
- Extraction: 82% EXTRACTED · 17% INFERRED · 1% AMBIGUOUS · INFERRED: 13 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9afef9ee`
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

## God Nodes (most connected - your core abstractions)
1. `Ansible Collections Requirements` - 9 edges
2. `Traefik Ingress Role Tasks` - 9 edges
3. `Global Cluster Variables` - 8 edges
4. `Playbook 03: Install Add-ons` - 8 edges
5. `Fixes Applied Documentation` - 7 edges
6. `Cilium Role Tasks` - 7 edges
7. `RKE2 Homelab README` - 5 edges
8. `Playbook 01: Prepare Nodes` - 5 edges
9. `Playbook 02: Install RKE2` - 5 edges
10. `Longhorn Role Tasks` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Pre-commit Config Hooks` --references--> `RKE2 Homelab README`  [AMBIGUOUS]
  .pre-commit-config.yaml → rke2-homelab-ansible/README.md
- `Global Cluster Variables` --shares_data_with--> `Cilium Role Defaults`  [INFERRED]
  rke2-homelab-ansible/group_vars/all.yml → rke2-homelab-ansible/roles/cilium/defaults/main.yml
- `Global Cluster Variables` --shares_data_with--> `RKE2 Master Role Defaults`  [INFERRED]
  rke2-homelab-ansible/group_vars/all.yml → rke2-homelab-ansible/roles/rke2-master/defaults/main.yml
- `Fixes Applied Documentation` --cites--> `Update Worker Config Playbook`  [EXTRACTED]
  rke2-homelab-ansible/FIXES-APPLIED.md → rke2-homelab-ansible/update-worker-config.yml
- `Global Cluster Variables` --shares_data_with--> `RKE2 Worker Role Defaults`  [INFERRED]
  rke2-homelab-ansible/group_vars/all.yml → rke2-homelab-ansible/roles/rke2-worker/defaults/main.yml

## Import Cycles
- None detected.

## Communities (18 total, 4 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.24
Nodes (12): Inventory Hosts Configuration, Playbook 01: Prepare Nodes, Playbook 02: Install RKE2, Pre-commit Config Hooks, RKE2 Quick Start Guide, Ansible Collections Requirements, RKE2 Homelab README, Common Role Defaults (+4 more)

### Community 1 - "Community 1"
Cohesion: 0.29
Nodes (10): Longhorn Distributed Storage, Traefik Ingress Controller, Fix Cert-Manager Playbook, Fixes Applied Documentation, Playbook 03: Install Add-ons, Longhorn Role Defaults, Longhorn Role Tasks, Test Apps Role Defaults (+2 more)

### Community 2 - "Community 2"
Cohesion: 0.25
Nodes (8): RKE2 Kubernetes Cluster, RKE2 Master Role Defaults, RKE2 Master Role Handlers, RKE2 Master Role Tasks, RKE2 Worker Role Defaults, RKE2 Worker Role Handlers, RKE2 Worker Role Tasks, Update Worker Config Playbook

### Community 3 - "Community 3"
Cohesion: 0.48
Nodes (7): cert-manager TLS Management, Cloudflare DNS Integration, Let's Encrypt ACME, Global Cluster Variables, RKE2 Masters Group Variables, RKE2 Workers Group Variables, Traefik Ingress Role Defaults

### Community 4 - "Community 4"
Cohesion: 0.60
Nodes (5): Cilium CNI, CoreDNS Cluster DNS, Deploy CoreDNS Playbook, Cilium Role Defaults, Cilium Role Tasks

## Ambiguous Edges - Review These
- `Pre-commit Config Hooks` → `RKE2 Homelab README`  [AMBIGUOUS]
  .pre-commit-config.yaml · relation: references

## Knowledge Gaps
- **15 isolated node(s):** `allow`, `apply-fixes.sh script`, `setup-rke2-ansible.sh script`, `Pre-commit Config Hooks`, `DNS Update README` (+10 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Pre-commit Config Hooks` and `RKE2 Homelab README`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `Ansible Collections Requirements` connect `Community 0` to `Community 1`, `Community 4`?**
  _High betweenness centrality (0.134) - this node is a cross-community bridge._
- **Why does `Traefik Ingress Role Tasks` connect `Community 1` to `Community 0`, `Community 3`?**
  _High betweenness centrality (0.119) - this node is a cross-community bridge._
- **Why does `Global Cluster Variables` connect `Community 3` to `Community 2`, `Community 4`?**
  _High betweenness centrality (0.087) - this node is a cross-community bridge._
- **Are the 6 inferred relationships involving `Global Cluster Variables` (e.g. with `Cilium Role Defaults` and `RKE2 Master Role Defaults`) actually correct?**
  _`Global Cluster Variables` has 6 INFERRED edges - model-reasoned connections that need verification._
- **What connects `allow`, `apply-fixes.sh script`, `setup-rke2-ansible.sh script` to the rest of the system?**
  _15 weakly-connected nodes found - possible documentation gaps or missing edges._