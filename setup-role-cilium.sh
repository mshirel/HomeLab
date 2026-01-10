#!/bin/bash
set -e

if [ ! -d "rke2-homelab-ansible/roles/cilium" ]; then
    echo "ERROR: rke2-homelab-ansible/roles/cilium directory not found!"
    echo "Please run the main setup script first."
    exit 1
fi

cd rke2-homelab-ansible/roles/cilium

echo "Creating Cilium role files..."

# defaults/main.yml
cat > defaults/main.yml << 'EOF'
---
# Cilium CNI defaults

cilium_version: "1.15.1"
cilium_namespace: kube-system

# Cilium configuration
cilium_ipv4_enabled: true
cilium_ipv6_enabled: false
cilium_tunnel_mode: vxlan
cilium_enable_hubble: true
cilium_enable_hubble_ui: false  # Can enable later for web UI
EOF

# tasks/main.yml
cat > tasks/main.yml << 'EOF'
---
- name: Add Cilium Helm repository
  kubernetes.core.helm_repository:
    name: cilium
    repo_url: https://helm.cilium.io/
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Deploy Cilium CNI
  kubernetes.core.helm:
    name: cilium
    chart_ref: cilium/cilium
    chart_version: "{{ cilium_version }}"
    release_namespace: "{{ cilium_namespace }}"
    create_namespace: false
    values:
      ipam:
        mode: kubernetes
      ipv4:
        enabled: "{{ cilium_ipv4_enabled }}"
      ipv6:
        enabled: "{{ cilium_ipv6_enabled }}"
      tunnel: "{{ cilium_tunnel_mode }}"
      hubble:
        enabled: "{{ cilium_enable_hubble }}"
        relay:
          enabled: "{{ cilium_enable_hubble }}"
        ui:
          enabled: "{{ cilium_enable_hubble_ui }}"
      operator:
        replicas: 2
      k8sServiceHost: "{{ kube_api_endpoint }}"
      k8sServicePort: "{{ kube_api_port }}"
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Wait for Cilium pods to be ready
  ansible.builtin.command: >
    kubectl wait --for=condition=ready pod
    -l k8s-app=cilium
    -n {{ cilium_namespace }}
    --timeout=300s
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  changed_when: false

- name: Verify Cilium status
  ansible.builtin.shell: |
    kubectl -n {{ cilium_namespace }} exec -it ds/cilium -- cilium status --brief
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  register: cilium_status
  changed_when: false
  failed_when: false

- name: Display Cilium status
  ansible.builtin.debug:
    msg: "{{ cilium_status.stdout_lines }}"
  when: cilium_status.rc == 0
EOF

echo "✓ Cilium role created successfully!"