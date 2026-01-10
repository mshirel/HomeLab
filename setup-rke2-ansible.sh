#!/bin/bash
set -e

echo "=========================================="
echo "RKE2 Homelab Ansible Project Setup"
echo "=========================================="
echo ""

# Check if directory exists
if [ -d "rke2-homelab-ansible" ]; then
    echo "ERROR: Directory 'rke2-homelab-ansible' already exists!"
    echo "Please remove it first or run this script from a different location."
    exit 1
fi

echo "Creating project structure..."

# Create base directory
mkdir -p rke2-homelab-ansible
cd rke2-homelab-ansible

# Create directory structure
mkdir -p inventory
mkdir -p group_vars
mkdir -p playbooks
mkdir -p files
mkdir -p roles/common/{defaults,tasks,handlers,templates}
mkdir -p roles/storage/{defaults,tasks}
mkdir -p roles/rke2-master/{defaults,tasks,handlers,templates}
mkdir -p roles/rke2-worker/{defaults,tasks,handlers,templates}
mkdir -p roles/cilium/{defaults,tasks}
mkdir -p roles/longhorn/{defaults,tasks,templates}
mkdir -p roles/traefik-ingress/{defaults,tasks,templates}
mkdir -p roles/test-apps/{defaults,tasks,templates}

echo "Creating files..."

# .gitignore
cat > .gitignore << 'EOF'
# Ansible
*.retry
.ansible/
/tmp/

# Python
__pycache__/
*.py[cod]
*$py.class
.Python
venv/
ENV/

# Secrets - NEVER commit these
*vault-pass*.txt
*.key
*.pem
*secret*
*token*

# Kubeconfig
*.kubeconfig
*-config
~/.kube/

# OS
.DS_Store
Thumbs.db
*.swp
*.swo
*~

# IDEs
.vscode/
.idea/
*.iml

# Logs
*.log

# Temporary files
tmp/
temp/
EOF

# ansible.cfg
cat > ansible.cfg << 'EOF'
[defaults]
inventory = inventory/hosts.yml
remote_user = ansible
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600
stdout_callback = yaml
callbacks_enabled = profile_tasks, timer
forks = 10
timeout = 30

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o ServerAliveInterval=60
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
EOF

# requirements.yml
cat > requirements.yml << 'EOF'
---
collections:
  - name: ansible.posix
    version: ">=1.5.0"
  - name: community.general
    version: ">=8.0.0"
  - name: kubernetes.core
    version: ">=3.0.0"
EOF

# inventory/hosts.yml
cat > inventory/hosts.yml << 'EOF'
---
all:
  children:
    rke2_cluster:
      children:
        rke2_masters:
          hosts:
            kube01-master01.tanx95.us:
            kube01-master02.tanx95.us:
            kube01-master03.tanx95.us:
        rke2_workers:
          hosts:
            kube01-worker01.tanx95.us:
            kube01-worker02.tanx95.us:
            kube01-worker03.tanx95.us:
EOF

# group_vars/all.yml
cat > group_vars/all.yml << 'EOF'
---
# Global Cluster Configuration

# Cluster Identity
cluster_name: kube01
cluster_domain: tanx95.us
cluster_fqdn: "{{ cluster_name }}.{{ cluster_domain }}"

# Kubernetes API Endpoint
kube_api_endpoint: "kube01-api.{{ cluster_domain }}"
kube_api_port: 6443

# RKE2 Configuration
rke2_version: stable
rke2_channel: stable

# Network Configuration
pod_cidr: "10.42.0.0/16"
service_cidr: "10.43.0.0/16"
cluster_dns: "10.43.0.10"

# Disable IPv6
disable_ipv6: true

# Firewall Configuration
firewall_enabled: true
firewall_default_policy: allow  # Permissive within cluster

# System Configuration
disable_swap: true
update_system_packages: true

# Time synchronization
configure_ntp: true

# Tools to install on all nodes
install_tools:
  - curl
  - wget
  - git
  - vim
  - htop
  - jq
  - net-tools
  - dnsutils

# Tools to install on master nodes
master_tools:
  - kubectl
  - helm
  - k9s

# Container runtime
container_runtime: containerd

# Storage Configuration (for Longhorn)
storage_device: /dev/sdb
storage_mount_point: /var/lib/longhorn
storage_filesystem: xfs

# Ingress Configuration
ingress_domain: "{{ cluster_name }}.{{ cluster_domain }}"
ingress_http_nodeport: 30080
ingress_https_nodeport: 30443

# Let's Encrypt Configuration
acme_email: "{{ lookup('env', 'ACME_EMAIL') | default('admin@' + cluster_domain, true) }}"
acme_server: "https://acme-v02.api.letsencrypt.org/directory"  # Production
# acme_server: "https://acme-staging-v02.api.letsencrypt.org/directory"  # Staging for testing

# Cloudflare Configuration (for DNS-01 challenge)
cloudflare_api_token: "{{ lookup('env', 'CLOUDFLARE_API_TOKEN') }}"

# Paths
rke2_config_dir: /etc/rancher/rke2
rke2_data_dir: /var/lib/rancher/rke2
kubeconfig_path: "{{ rke2_config_dir }}/rke2.yaml"
local_kubeconfig_path: "~/.kube/{{ cluster_name }}-config"
EOF

# group_vars/rke2_masters.yml
cat > group_vars/rke2_masters.yml << 'EOF'
---
# RKE2 Master Node Configuration

# Node role
rke2_type: server

# Taint masters to prevent workload scheduling
taint_masters: true
master_node_taints:
  - "node-role.kubernetes.io/control-plane:NoSchedule"

# etcd snapshot configuration
etcd_snapshot_schedule_cron: "0 */12 * * *"  # Every 12 hours
etcd_snapshot_retention: 5

# Control plane resource reservations
kube_reserved:
  cpu: "500m"
  memory: "512Mi"
system_reserved:
  cpu: "500m"
  memory: "512Mi"
EOF

# group_vars/rke2_workers.yml
cat > group_vars/rke2_workers.yml << 'EOF'
---
# RKE2 Worker Node Configuration

# Node role
rke2_type: agent

# Storage configuration
setup_storage: true
storage_enabled: true

# Labels for worker nodes
worker_node_labels:
  node-role.kubernetes.io/worker: "true"
  storage-node: "true"
EOF

# playbooks/01-prepare-nodes.yml
cat > playbooks/01-prepare-nodes.yml << 'EOF'
---
- name: Prepare all nodes for RKE2 installation
  hosts: rke2_cluster
  gather_facts: true
  become: true

  pre_tasks:
    - name: Display preparation start message
      ansible.builtin.debug:
        msg: "Starting system preparation for {{ inventory_hostname }}"

  roles:
    - role: common
      tags: [common, system]

  tasks:
    - name: Display preparation completion
      ansible.builtin.debug:
        msg: "System preparation completed for {{ inventory_hostname }}"

- name: Setup storage on worker nodes
  hosts: rke2_workers
  gather_facts: true
  become: true

  roles:
    - role: storage
      tags: [storage]

  tasks:
    - name: Verify storage mount
      ansible.builtin.command: df -h {{ storage_mount_point }}
      register: storage_df
      changed_when: false

    - name: Display storage information
      ansible.builtin.debug:
        msg: "{{ storage_df.stdout_lines }}"
EOF

# playbooks/02-install-rke2.yml
cat > playbooks/02-install-rke2.yml << 'EOF'
---
- name: Install RKE2 on first master
  hosts: rke2_masters[0]
  gather_facts: true
  become: true

  roles:
    - role: rke2-master
      tags: [rke2, master, first-master]

  tasks:
    - name: Wait for first master to be ready
      ansible.builtin.wait_for:
        host: "{{ ansible_default_ipv4.address }}"
        port: 6443
        timeout: 300

    - name: Get cluster token
      ansible.builtin.slurp:
        src: /var/lib/rancher/rke2/server/node-token
      register: node_token_raw

    - name: Set cluster token fact
      ansible.builtin.set_fact:
        cluster_token: "{{ node_token_raw.content | b64decode | trim }}"

    - name: Display first master status
      ansible.builtin.debug:
        msg: "First master {{ inventory_hostname }} is ready"

- name: Install RKE2 on additional masters
  hosts: rke2_masters[1:]
  gather_facts: true
  become: true
  serial: 1

  tasks:
    - name: Set cluster token from first master
      ansible.builtin.set_fact:
        cluster_token: "{{ hostvars[groups['rke2_masters'][0]]['cluster_token'] }}"

  roles:
    - role: rke2-master
      tags: [rke2, master, additional-masters]

  tasks:
    - name: Wait for master to be ready
      ansible.builtin.wait_for:
        host: "{{ ansible_default_ipv4.address }}"
        port: 6443
        timeout: 300

    - name: Display master status
      ansible.builtin.debug:
        msg: "Master {{ inventory_hostname }} joined the cluster"

- name: Install RKE2 on worker nodes
  hosts: rke2_workers
  gather_facts: true
  become: true
  serial: 2

  tasks:
    - name: Set cluster token from first master
      ansible.builtin.set_fact:
        cluster_token: "{{ hostvars[groups['rke2_masters'][0]]['cluster_token'] }}"

  roles:
    - role: rke2-worker
      tags: [rke2, worker]

  tasks:
    - name: Display worker status
      ansible.builtin.debug:
        msg: "Worker {{ inventory_hostname }} joined the cluster"

- name: Fetch kubeconfig and verify cluster
  hosts: rke2_masters[0]
  gather_facts: false
  become: true

  tasks:
    - name: Fetch kubeconfig to local machine
      ansible.builtin.fetch:
        src: "{{ kubeconfig_path }}"
        dest: "{{ local_kubeconfig_path }}"
        flat: true

    - name: Replace server address in kubeconfig
      delegate_to: localhost
      become: false
      ansible.builtin.replace:
        path: "{{ local_kubeconfig_path }}"
        regexp: 'https://127\.0\.0\.1:6443'
        replace: "https://{{ kube_api_endpoint }}:{{ kube_api_port }}"

    - name: Set kubeconfig permissions
      delegate_to: localhost
      become: false
      ansible.builtin.file:
        path: "{{ local_kubeconfig_path }}"
        mode: '0600'

    - name: Wait for all nodes to be ready
      ansible.builtin.command: >
        kubectl get nodes --no-headers
      register: nodes_status
      until: nodes_status.stdout_lines | length == groups['rke2_cluster'] | length
      retries: 30
      delay: 10
      changed_when: false
      environment:
        KUBECONFIG: "{{ kubeconfig_path }}"

    - name: Display cluster nodes
      ansible.builtin.command: kubectl get nodes -o wide
      register: cluster_nodes
      changed_when: false
      environment:
        KUBECONFIG: "{{ kubeconfig_path }}"

    - name: Show cluster status
      ansible.builtin.debug:
        msg: "{{ cluster_nodes.stdout_lines }}"

    - name: Display kubeconfig location
      ansible.builtin.debug:
        msg: |
          Kubeconfig saved to: {{ local_kubeconfig_path }}
          
          To use kubectl from your local machine:
          export KUBECONFIG={{ local_kubeconfig_path }}
          kubectl get nodes
EOF

# playbooks/03-install-addons.yml
cat > playbooks/03-install-addons.yml << 'EOF'
---
- name: Install Kubernetes add-ons and applications
  hosts: rke2_masters[0]
  gather_facts: true
  become: true

  pre_tasks:
    - name: Display add-on installation start
      ansible.builtin.debug:
        msg: "Starting installation of cluster add-ons"

    - name: Verify kubectl is available
      ansible.builtin.command: kubectl version --client
      register: kubectl_version
      changed_when: false
      environment:
        KUBECONFIG: "{{ kubeconfig_path }}"

  roles:
    - role: cilium
      tags: [cilium, cni, networking]

    - role: longhorn
      tags: [longhorn, storage]

    - role: traefik-ingress
      tags: [traefik, ingress]

    - role: test-apps
      tags: [test-apps, apps]

  post_tasks:
    - name: Wait for all pods to be running
      ansible.builtin.shell: |
        kubectl get pods -A --no-headers | grep -v "Running\|Completed" || true
      register: pending_pods
      until: pending_pods.stdout_lines | length == 0
      retries: 30
      delay: 10
      changed_when: false
      environment:
        KUBECONFIG: "{{ kubeconfig_path }}"

    - name: Get all pods status
      ansible.builtin.command: kubectl get pods -A -o wide
      register: all_pods
      changed_when: false
      environment:
        KUBECONFIG: "{{ kubeconfig_path }}"

    - name: Display all pods
      ansible.builtin.debug:
        msg: "{{ all_pods.stdout_lines }}"

    - name: Get ingress resources
      ansible.builtin.command: kubectl get ingress -A
      register: ingress_resources
      changed_when: false
      environment:
        KUBECONFIG: "{{ kubeconfig_path }}"

    - name: Display ingress resources
      ansible.builtin.debug:
        msg: "{{ ingress_resources.stdout_lines }}"

    - name: Display access information
      ansible.builtin.debug:
        msg: |
          ========================================
          Cluster Setup Complete!
          ========================================
          
          Longhorn UI: https://longhorn.{{ ingress_domain }}
          Test App 1:  https://nginx.{{ ingress_domain }}
          Test App 2:  https://nginx-pvc.{{ ingress_domain }}
          
          Next steps:
          1. Configure external Traefik to forward *.{{ ingress_domain }} to workers on ports {{ ingress_http_nodeport }}/{{ ingress_https_nodeport }}
          2. Verify DNS records for the above domains
          3. Wait a few minutes for Let's Encrypt certificates to be issued
          4. Access the applications via HTTPS
          
          Useful commands:
          - kubectl get nodes
          - kubectl get pods -A
          - kubectl -n kube-system exec -it ds/cilium -- cilium status
          - hubble observe
          - k9s (on master nodes)
EOF

# roles/common/defaults/main.yml
cat > roles/common/defaults/main.yml << 'EOF'
---
# Common role defaults

# System update
update_cache: true
upgrade_packages: false  # Set to true for full upgrade

# IPv6
ipv6_disable: true

# Swap
swap_disable: true

# Firewall
setup_firewall: true
ssh_port: 22

# Required kernel modules
kernel_modules:
  - overlay
  - br_netfilter

# Sysctl parameters
sysctl_config:
  net.bridge.bridge-nf-call-iptables: 1
  net.bridge.bridge-nf-call-ip6tables: 1
  net.ipv4.ip_forward: 1
  net.ipv6.conf.all.disable_ipv6: 1
  net.ipv6.conf.default.disable_ipv6: 1
  net.ipv6.conf.lo.disable_ipv6: 1
  fs.inotify.max_user_watches: 524288
  fs.inotify.max_user_instances: 512

# Base packages to install
base_packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - software-properties-common
  - nfs-common
  - open-iscsi
EOF

# roles/common/tasks/main.yml
cat > roles/common/tasks/main.yml << 'EOF'
---
- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600
  when: update_cache | bool

- name: Upgrade all packages
  ansible.builtin.apt:
    upgrade: dist
    autoremove: true
    autoclean: true
  when: upgrade_packages | bool

- name: Install base packages
  ansible.builtin.apt:
    name: "{{ base_packages }}"
    state: present

- name: Install additional tools
  ansible.builtin.apt:
    name: "{{ install_tools }}"
    state: present
  when: install_tools is defined

- name: Disable IPv6 via sysctl
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    state: present
    reload: true
  loop: "{{ sysctl_config | dict2items }}"
  when: 
    - ipv6_disable | bool
    - "'ipv6' in item.key"

- name: Disable swap
  ansible.builtin.command: swapoff -a
  when: swap_disable | bool
  changed_when: false

- name: Remove swap from fstab
  ansible.builtin.lineinfile:
    path: /etc/fstab
    regexp: '^\s*[^#].*\s+swap\s+'
    state: absent
  when: swap_disable | bool

- name: Load required kernel modules
  community.general.modprobe:
    name: "{{ item }}"
    state: present
    persistent: present
  loop: "{{ kernel_modules }}"

- name: Configure sysctl parameters
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    state: present
    reload: true
  loop: "{{ sysctl_config | dict2items }}"
  when: "'ipv6' not in item.key or ipv6_disable | bool"

- name: Setup UFW firewall
  when: setup_firewall | bool
  block:
    - name: Install UFW
      ansible.builtin.apt:
        name: ufw
        state: present

    - name: Allow SSH
      community.general.ufw:
        rule: allow
        port: "{{ ssh_port }}"
        proto: tcp

    - name: Allow all traffic between cluster nodes
      community.general.ufw:
        rule: allow
        from_ip: "{{ hostvars[item].ansible_default_ipv4.address }}"
      loop: "{{ groups['rke2_cluster'] }}"
      when: hostvars[item].ansible_default_ipv4.address is defined

    - name: Set UFW default policy
      community.general.ufw:
        state: enabled
        policy: "{{ firewall_default_policy }}"

- name: Ensure systemd-timesyncd is running
  ansible.builtin.systemd:
    name: systemd-timesyncd
    state: started
    enabled: true
  when: configure_ntp | default(true) | bool

- name: Check if reboot is required
  ansible.builtin.stat:
    path: /var/run/reboot-required
  register: reboot_required

- name: Notify if reboot needed
  ansible.builtin.debug:
    msg: "WARNING: System reboot required but not performing automatic reboot"
  when: reboot_required.stat.exists
EOF

# roles/common/handlers/main.yml
cat > roles/common/handlers/main.yml << 'EOF'
---
# Common role handlers

- name: Reload systemd
  ansible.builtin.systemd:
    daemon_reload: true

- name: Reload sysctl
  ansible.builtin.command: sysctl -p
  changed_when: false

- name: Reload ufw
  ansible.builtin.systemd:
    name: ufw
    state: reloaded
EOF

# roles/storage/defaults/main.yml
cat > roles/storage/defaults/main.yml << 'EOF'
---
# Storage role defaults

# Storage device configuration
# storage_device: /dev/sdb  # Defined in group_vars
# storage_mount_point: /var/lib/longhorn  # Defined in group_vars
# storage_filesystem: xfs  # Defined in group_vars

# Check before formatting
check_existing_filesystem: true
force_format: false
EOF

# roles/storage/tasks/main.yml
cat > roles/storage/tasks/main.yml << 'EOF'
---
- name: Check if storage device exists
  ansible.builtin.stat:
    path: "{{ storage_device }}"
  register: storage_device_stat

- name: Fail if storage device doesn't exist
  ansible.builtin.fail:
    msg: "Storage device {{ storage_device }} not found. Please add the disk to the VM."
  when: not storage_device_stat.stat.exists

- name: Check if device is already mounted
  ansible.builtin.shell: |
    mount | grep "{{ storage_mount_point }}" || true
  register: mount_check
  changed_when: false

- name: Check if device has a filesystem
  ansible.builtin.command: blkid {{ storage_device }}
  register: blkid_output
  changed_when: false
  failed_when: false

- name: Display device status
  ansible.builtin.debug:
    msg: "Device {{ storage_device }} filesystem status: {{ 'formatted' if blkid_output.rc == 0 else 'unformatted' }}"

- name: Create filesystem on storage device
  community.general.filesystem:
    fstype: "{{ storage_filesystem }}"
    dev: "{{ storage_device }}"
    force: "{{ force_format }}"
  when: 
    - blkid_output.rc != 0 or force_format
    - mount_check.stdout == ""

- name: Create mount point directory
  ansible.builtin.file:
    path: "{{ storage_mount_point }}"
    state: directory
    mode: '0755'

- name: Mount storage device
  ansible.posix.mount:
    path: "{{ storage_mount_point }}"
    src: "{{ storage_device }}"
    fstype: "{{ storage_filesystem }}"
    state: mounted
    opts: defaults,noatime

- name: Ensure mount point has correct permissions
  ansible.builtin.file:
    path: "{{ storage_mount_point }}"
    state: directory
    mode: '0755'
    owner: root
    group: root

- name: Verify mount
  ansible.builtin.command: df -h {{ storage_mount_point }}
  register: df_output
  changed_when: false

- name: Display mount information
  ansible.builtin.debug:
    msg: "{{ df_output.stdout_lines }}"
EOF

echo "Project structure created successfully!"
echo ""
echo "Files created in: $(pwd)"
echo ""
echo "Due to script length limitations, this script creates the core structure."
echo "You'll need to run part 2 of the setup script to complete the installation."
echo ""
echo "Creating part 2 script..."

# Create part 2 script
cat > ../setup-rke2-ansible-part2.sh << 'PART2EOF'
#!/bin/bash
set -e

if [ ! -d "rke2-homelab-ansible" ]; then
    echo "ERROR: rke2-homelab-ansible directory not found!"
    echo "Please run setup-rke2-ansible.sh first."
    exit 1
fi

cd rke2-homelab-ansible

echo "Continuing setup - Creating RKE2 roles..."

# Due to file length, this script will be created in the next message

PART2EOF

chmod +x ../setup-rke2-ansible-part2.sh

echo ""
echo "=========================================="
echo "Base structure created successfully!"
echo "=========================================="
echo ""
echo "Core files created. Role-specific scripts will add the rest."