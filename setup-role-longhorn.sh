#!/bin/bash
set -e

if [ ! -d "rke2-homelab-ansible/roles/longhorn" ]; then
    echo "ERROR: rke2-homelab-ansible/roles/longhorn directory not found!"
    echo "Please run the main setup script first."
    exit 1
fi

cd rke2-homelab-ansible/roles/longhorn

echo "Creating Longhorn role files..."

# defaults/main.yml
cat > defaults/main.yml << 'EOF'
---
# Longhorn storage defaults

longhorn_version: "1.6.0"
longhorn_namespace: longhorn-system

# Storage configuration
longhorn_default_replica_count: 3
longhorn_default_data_locality: best-effort
longhorn_default_reclaim_policy: Retain

# Node selector - only workers
longhorn_node_selector: "storage-node=true"

# UI configuration
longhorn_ui_enabled: true
longhorn_ui_ingress_host: "longhorn.{{ ingress_domain }}"
EOF

# tasks/main.yml
cat > tasks/main.yml << 'EOF'
---
- name: Create Longhorn namespace
  kubernetes.core.k8s:
    name: "{{ longhorn_namespace }}"
    api_version: v1
    kind: Namespace
    state: present
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Add Longhorn Helm repository
  kubernetes.core.helm_repository:
    name: longhorn
    repo_url: https://charts.longhorn.io
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Deploy Longhorn
  kubernetes.core.helm:
    name: longhorn
    chart_ref: longhorn/longhorn
    chart_version: "{{ longhorn_version }}"
    release_namespace: "{{ longhorn_namespace }}"
    create_namespace: false
    values:
      defaultSettings:
        defaultReplicaCount: "{{ longhorn_default_replica_count }}"
        defaultDataLocality: "{{ longhorn_default_data_locality }}"
        defaultLonghornStaticStorageClass: longhorn
      longhornManager:
        nodeSelector:
          storage-node: "true"
      longhornDriver:
        nodeSelector:
          storage-node: "true"
      persistence:
        defaultClass: true
        defaultClassReplicaCount: "{{ longhorn_default_replica_count }}"
        reclaimPolicy: "{{ longhorn_default_reclaim_policy }}"
      ingress:
        enabled: false  # We'll create our own ingress
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Wait for Longhorn to be ready
  ansible.builtin.command: >
    kubectl wait --for=condition=ready pod
    -l app=longhorn-manager
    -n {{ longhorn_namespace }}
    --timeout=600s
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  changed_when: false

- name: Create Longhorn UI ingress
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('template', 'longhorn-ingress.yaml.j2') | from_yaml }}"
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  when: longhorn_ui_enabled | bool

- name: Get Longhorn system status
  ansible.builtin.command: kubectl get pods -n {{ longhorn_namespace }}
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  register: longhorn_pods
  changed_when: false

- name: Display Longhorn status
  ansible.builtin.debug:
    msg: "{{ longhorn_pods.stdout_lines }}"
EOF

# templates/longhorn-ingress.yaml.j2
cat > templates/longhorn-ingress.yaml.j2 << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: {{ longhorn_namespace }}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - {{ longhorn_ui_ingress_host }}
      secretName: longhorn-tls
  rules:
    - host: {{ longhorn_ui_ingress_host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: longhorn-frontend
                port:
                  number: 80
EOF

echo "✓ Longhorn role created successfully!"