#!/bin/bash
set -e

if [ ! -d "rke2-homelab-ansible/roles/rke2-worker" ]; then
    echo "ERROR: rke2-homelab-ansible/roles/rke2-worker directory not found!"
    echo "Please run the main setup script first."
    exit 1
fi

cd rke2-homelab-ansible/roles/rke2-worker

echo "Creating RKE2 Worker role files..."

# defaults/main.yml
cat > defaults/main.yml << 'EOF'
---
# RKE2 Worker defaults

rke2_install_script_url: https://get.rke2.io
EOF

# tasks/main.yml
cat > tasks/main.yml << 'EOF'
---
- name: Check if RKE2 agent is already installed
  ansible.builtin.stat:
    path: /usr/local/bin/rke2
  register: rke2_binary

- name: Download RKE2 installation script
  ansible.builtin.get_url:
    url: "{{ rke2_install_script_url }}"
    dest: /tmp/rke2-install.sh
    mode: '0700'
  when: not rke2_binary.stat.exists

- name: Install RKE2 agent
  ansible.builtin.command: /tmp/rke2-install.sh
  environment:
    INSTALL_RKE2_CHANNEL: "{{ rke2_channel }}"
    INSTALL_RKE2_TYPE: agent
  when: not rke2_binary.stat.exists
  register: rke2_install

- name: Create RKE2 config directory
  ansible.builtin.file:
    path: "{{ rke2_config_dir }}"
    state: directory
    mode: '0755'

- name: Deploy RKE2 agent config
  ansible.builtin.template:
    src: config-agent.yaml.j2
    dest: "{{ rke2_config_dir }}/config.yaml"
    mode: '0600'

- name: Enable and start RKE2 agent service
  ansible.builtin.systemd:
    name: rke2-agent
    enabled: true
    state: started
  register: rke2_service

- name: Wait for node to join cluster
  ansible.builtin.pause:
    seconds: 30

- name: Create kubectl symlink
  ansible.builtin.file:
    src: /var/lib/rancher/rke2/bin/kubectl
    dest: /usr/local/bin/kubectl
    state: link

- name: Install crictl
  block:
    - name: Download crictl
      ansible.builtin.get_url:
        url: https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.29.0/crictl-v1.29.0-linux-amd64.tar.gz
        dest: /tmp/crictl.tar.gz
        mode: '0644'

    - name: Extract crictl
      ansible.builtin.unarchive:
        src: /tmp/crictl.tar.gz
        dest: /usr/local/bin
        remote_src: true
        creates: /usr/local/bin/crictl
EOF

# handlers/main.yml
cat > handlers/main.yml << 'EOF'
---
# RKE2 Worker handlers

- name: Restart rke2-agent
  ansible.builtin.systemd:
    name: rke2-agent
    state: restarted

- name: Reload rke2-agent
  ansible.builtin.systemd:
    name: rke2-agent
    state: reloaded
EOF

# templates/config-agent.yaml.j2
cat > templates/config-agent.yaml.j2 << 'EOF'
# RKE2 Agent Configuration
node-name: {{ inventory_hostname }}
node-ip: {{ ansible_default_ipv4.address }}

# Join cluster
server: https://{{ groups['rke2_masters'][0] }}:9345
token: {{ cluster_token }}

# Node labels
node-label:
{% for label_key, label_value in worker_node_labels.items() %}
  - "{{ label_key }}={{ label_value }}"
{% endfor %}

# Kubelet configuration
kubelet-arg:
  - "node-ip={{ ansible_default_ipv4.address }}"
EOF

echo "✓ RKE2 Worker role created successfully!"