#!/bin/bash
set -e

if [ ! -d "rke2-homelab-ansible/roles/rke2-master" ]; then
    echo "ERROR: rke2-homelab-ansible/roles/rke2-master directory not found!"
    echo "Please run the main setup script first."
    exit 1
fi

cd rke2-homelab-ansible/roles/rke2-master

echo "Creating RKE2 Master role files..."

# defaults/main.yml
cat > defaults/main.yml << 'EOF'
---
# RKE2 Master defaults

rke2_install_script_url: https://get.rke2.io

# CNI configuration - we'll install Cilium separately
rke2_cni: none

# Disable components we'll install manually
disable_components:
  - rke2-canal
  - rke2-coredns
  - rke2-ingress-nginx
  - rke2-metrics-server

# TLS SANs for API server certificate
tls_san:
  - "{{ kube_api_endpoint }}"
  - "{{ inventory_hostname }}"
EOF

# tasks/main.yml
cat > tasks/main.yml << 'EOF'
---
- name: Check if RKE2 is already installed
  ansible.builtin.stat:
    path: /usr/local/bin/rke2
  register: rke2_binary

- name: Download RKE2 installation script
  ansible.builtin.get_url:
    url: "{{ rke2_install_script_url }}"
    dest: /tmp/rke2-install.sh
    mode: '0700'
  when: not rke2_binary.stat.exists

- name: Install RKE2
  ansible.builtin.command: /tmp/rke2-install.sh
  environment:
    INSTALL_RKE2_CHANNEL: "{{ rke2_channel }}"
    INSTALL_RKE2_TYPE: server
  when: not rke2_binary.stat.exists
  register: rke2_install

- name: Create RKE2 config directory
  ansible.builtin.file:
    path: "{{ rke2_config_dir }}"
    state: directory
    mode: '0755'

- name: Deploy RKE2 config for first master
  ansible.builtin.template:
    src: config-first-master.yaml.j2
    dest: "{{ rke2_config_dir }}/config.yaml"
    mode: '0600'
  when: inventory_hostname == groups['rke2_masters'][0]

- name: Deploy RKE2 config for additional masters
  ansible.builtin.template:
    src: config-additional-master.yaml.j2
    dest: "{{ rke2_config_dir }}/config.yaml"
    mode: '0600'
  when: inventory_hostname != groups['rke2_masters'][0]

- name: Enable and start RKE2 server service
  ansible.builtin.systemd:
    name: rke2-server
    enabled: true
    state: started
  register: rke2_service

- name: Wait for RKE2 to be ready
  ansible.builtin.wait_for:
    path: "{{ kubeconfig_path }}"
    timeout: 300

- name: Create kubectl symlink
  ansible.builtin.file:
    src: /var/lib/rancher/rke2/bin/kubectl
    dest: /usr/local/bin/kubectl
    state: link

- name: Install kubectl bash completion
  ansible.builtin.shell: kubectl completion bash > /etc/bash_completion.d/kubectl
  args:
    creates: /etc/bash_completion.d/kubectl

- name: Install Helm
  when: "'helm' in master_tools | default([])"
  block:
    - name: Download Helm installation script
      ansible.builtin.get_url:
        url: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        dest: /tmp/get-helm-3.sh
        mode: '0700'

    - name: Install Helm
      ansible.builtin.command: /tmp/get-helm-3.sh
      args:
        creates: /usr/local/bin/helm

- name: Install k9s
  when: "'k9s' in master_tools | default([])"
  block:
    - name: Get latest k9s release
      ansible.builtin.uri:
        url: https://api.github.com/repos/derailed/k9s/releases/latest
        return_content: true
      register: k9s_release

    - name: Download k9s
      ansible.builtin.get_url:
        url: "{{ k9s_release.json.assets | selectattr('name', 'match', '.*Linux_amd64.tar.gz$') | map(attribute='browser_download_url') | first }}"
        dest: /tmp/k9s.tar.gz
        mode: '0644'

    - name: Extract k9s
      ansible.builtin.unarchive:
        src: /tmp/k9s.tar.gz
        dest: /usr/local/bin
        remote_src: true
        creates: /usr/local/bin/k9s

- name: Install Hubble CLI
  block:
    - name: Get latest Hubble release
      ansible.builtin.uri:
        url: https://api.github.com/repos/cilium/hubble/releases/latest
        return_content: true
      register: hubble_release

    - name: Download Hubble CLI
      ansible.builtin.get_url:
        url: "{{ hubble_release.json.assets | selectattr('name', 'match', '.*linux-amd64.tar.gz$') | map(attribute='browser_download_url') | first }}"
        dest: /tmp/hubble.tar.gz
        mode: '0644'

    - name: Extract Hubble CLI
      ansible.builtin.unarchive:
        src: /tmp/hubble.tar.gz
        dest: /usr/local/bin
        remote_src: true
        creates: /usr/local/bin/hubble

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

- name: Apply node taints
  ansible.builtin.command: >
    kubectl taint nodes {{ inventory_hostname }}
    {{ item }}
    --overwrite
  loop: "{{ master_node_taints }}"
  when: 
    - taint_masters | default(false) | bool
    - master_node_taints is defined
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  changed_when: true
  failed_when: false
EOF

# handlers/main.yml
cat > handlers/main.yml << 'EOF'
---
# RKE2 Master handlers

- name: Restart rke2-server
  ansible.builtin.systemd:
    name: rke2-server
    state: restarted

- name: Reload rke2-server
  ansible.builtin.systemd:
    name: rke2-server
    state: reloaded
EOF

# templates/config-first-master.yaml.j2
cat > templates/config-first-master.yaml.j2 << 'EOF'
# RKE2 Server Configuration - First Master
node-name: {{ inventory_hostname }}
node-ip: {{ ansible_default_ipv4.address }}

# Cluster configuration
cluster-cidr: {{ pod_cidr }}
service-cidr: {{ service_cidr }}
cluster-dns: {{ cluster_dns }}

# TLS configuration
tls-san:
{% for san in tls_san %}
  - {{ san }}
{% endfor %}

# CNI configuration
cni: {{ rke2_cni }}

# Disable default components
disable:
{% for component in disable_components %}
  - {{ component }}
{% endfor %}

# etcd snapshot configuration
etcd-snapshot-schedule-cron: "{{ etcd_snapshot_schedule_cron | default('0 */12 * * *') }}"
etcd-snapshot-retention: {{ etcd_snapshot_retention | default(5) }}

# Kubelet configuration
kubelet-arg:
  - "node-ip={{ ansible_default_ipv4.address }}"
EOF

# templates/config-additional-master.yaml.j2
cat > templates/config-additional-master.yaml.j2 << 'EOF'
# RKE2 Server Configuration - Additional Master
node-name: {{ inventory_hostname }}
node-ip: {{ ansible_default_ipv4.address }}

# Join existing cluster
server: https://{{ groups['rke2_masters'][0] }}:9345
token: {{ cluster_token }}

# TLS configuration
tls-san:
{% for san in tls_san %}
  - {{ san }}
{% endfor %}

# CNI configuration
cni: {{ rke2_cni }}

# Disable default components
disable:
{% for component in disable_components %}
  - {{ component }}
{% endfor %}

# Kubelet configuration
kubelet-arg:
  - "node-ip={{ ansible_default_ipv4.address }}"
EOF

echo "✓ RKE2 Master role created successfully!"