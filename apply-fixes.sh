#!/bin/bash
set -e

echo "Applying ansible-lint fixes..."

if [ ! -d "roles/common" ]; then
    echo "ERROR: Must run from rke2-homelab-ansible directory"
    exit 1
fi

# Backup originals
echo "Creating backups..."
cp roles/common/defaults/main.yml roles/common/defaults/main.yml.bak
cp roles/common/tasks/main.yml roles/common/tasks/main.yml.bak
cp roles/storage/defaults/main.yml roles/storage/defaults/main.yml.bak
cp roles/storage/tasks/main.yml roles/storage/tasks/main.yml.bak
cp .ansible-lint .ansible-lint.bak

echo "Applying fixes to roles/common/defaults/main.yml..."
cat > roles/common/defaults/main.yml << 'EOF'
---
# Common role defaults

# System update
common_update_cache: true
common_upgrade_packages: false  # Set to true for full upgrade

# IPv6
common_ipv6_disable: true

# Swap
common_swap_disable: true

# Firewall
common_setup_firewall: true
common_ssh_port: 22

# Required kernel modules
common_kernel_modules:
  - overlay
  - br_netfilter

# Sysctl parameters
common_sysctl_config:
  net.bridge.bridge-nf-call-iptables: 1
  net.bridge.bridge-nf-call-ip6tables: 1
  net.ipv4.ip_forward: 1
  net.ipv6.conf.all.disable_ipv6: 1
  net.ipv6.conf.default.disable_ipv6: 1
  net.ipv6.conf.lo.disable_ipv6: 1
  fs.inotify.max_user_watches: 524288
  fs.inotify.max_user_instances: 512

# Base packages to install
common_base_packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - software-properties-common
  - nfs-common
  - open-iscsi
EOF

echo "Applying fixes to roles/common/tasks/main.yml..."
cat > roles/common/tasks/main.yml << 'EOF'
---
- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600
  when: common_update_cache | bool

- name: Upgrade all packages
  ansible.builtin.apt:
    upgrade: dist
    autoremove: true
    autoclean: true
  when: common_upgrade_packages | bool

- name: Install base packages
  ansible.builtin.apt:
    name: "{{ common_base_packages }}"
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
  loop: "{{ common_sysctl_config | dict2items }}"
  when:
    - common_ipv6_disable | bool
    - "'ipv6' in item.key"

- name: Disable swap
  ansible.builtin.command: swapoff -a
  when: common_swap_disable | bool
  changed_when: false

- name: Remove swap from fstab
  ansible.builtin.lineinfile:
    path: /etc/fstab
    regexp: '^\s*[^#].*\s+swap\s+'
    state: absent
  when: common_swap_disable | bool

- name: Load required kernel modules
  community.general.modprobe:
    name: "{{ item }}"
    state: present
    persistent: present
  loop: "{{ common_kernel_modules }}"

- name: Configure sysctl parameters
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    state: present
    reload: true
  loop: "{{ common_sysctl_config | dict2items }}"
  when: "'ipv6' not in item.key or common_ipv6_disable | bool"

- name: Setup UFW firewall
  when: common_setup_firewall | bool
  block:
    - name: Install UFW
      ansible.builtin.apt:
        name: ufw
        state: present

    - name: Allow SSH
      community.general.ufw:
        rule: allow
        port: "{{ common_ssh_port }}"
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
  register: common_reboot_required

- name: Notify if reboot needed
  ansible.builtin.debug:
    msg: "WARNING: System reboot required but not performing automatic reboot"
  when: common_reboot_required.stat.exists
EOF

echo "Applying fixes to roles/storage/defaults/main.yml..."
cat > roles/storage/defaults/main.yml << 'EOF'
---
# Storage role defaults

# Storage device configuration
# storage_device: /dev/sdb  # Defined in group_vars
# storage_mount_point: /var/lib/longhorn  # Defined in group_vars
# storage_filesystem: xfs  # Defined in group_vars

# Check before formatting
storage_check_existing_filesystem: true
storage_force_format: false
EOF

echo "Applying fixes to roles/storage/tasks/main.yml..."
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
  ansible.builtin.command: findmnt -rn -S {{ storage_device }}
  register: storage_mount_check
  changed_when: false
  failed_when: false

- name: Check if device has a filesystem
  ansible.builtin.command: blkid {{ storage_device }}
  register: storage_blkid_output
  changed_when: false
  failed_when: false

- name: Display device status
  ansible.builtin.debug:
    msg: "Device {{ storage_device }} filesystem status: {{ 'formatted' if storage_blkid_output.rc == 0 else 'unformatted' }}"

- name: Create filesystem on storage device
  community.general.filesystem:
    fstype: "{{ storage_filesystem }}"
    dev: "{{ storage_device }}"
    force: "{{ storage_force_format }}"
  when:
    - storage_blkid_output.rc != 0 or storage_force_format
    - storage_mount_check.rc != 0

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
  register: storage_df_output
  changed_when: false

- name: Display mount information
  ansible.builtin.debug:
    msg: "{{ storage_df_output.stdout_lines }}"
EOF

echo "Applying fixes to .ansible-lint..."
cat > .ansible-lint << 'EOF'
---
# Ansible-lint configuration

# Skip list - only for legitimate exceptions
skip_list:
  - role-name[path]  # Allow hyphens in role names (rke2-master is clearer than rke2_master)

# Use min profile for basic checks
profile: min

# Exclude certain paths
exclude_paths:
  - .git/
  - .github/
  - files/

# Note: Install collections to resolve syntax-check warnings:
# ansible-galaxy collection install -r requirements.yml
EOF

echo ""
echo "✓ Fixes applied successfully!"
echo ""
echo "Backups saved with .bak extension"
echo ""
echo "Now run: ansible-galaxy collection install -r requirements.yml"
echo "Then: ansible-lint"