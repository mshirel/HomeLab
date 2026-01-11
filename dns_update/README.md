# DNS Resolver Update Playbook

This Ansible playbook updates DNS resolver configuration across your homelab infrastructure, replacing Pi-hole DNS servers with your UniFi Gateway DNS.

## What It Does

- Replaces old Pi-hole DNS servers (10.20.111.49, 10.20.10.33, 10.20.10.34) with UniFi Gateway (10.20.10.1)
- Sets search domain to tanx95.us for hostname resolution
- Supports multiple DNS configuration methods:
  - systemd-resolved (modern Ubuntu/Debian)
  - /etc/resolv.conf (traditional)
  - resolvconf (Debian/Ubuntu)
  - NetworkManager (RHEL/CentOS/Rocky)
  - /etc/network/interfaces (Proxmox/Debian)
  - netplan (Ubuntu 18.04+)
- Option to switch from static DNS to DHCP-managed DNS
- Creates backups before making changes

## Files

- `update_dns_resolvers.yml` - Main playbook
- `resolv.conf.j2` - Template for resolv.conf
- `inventory.ini` - Example inventory file

## Usage

### Option 1: Update to Static Gateway DNS (10.20.10.1)

```bash
ansible-playbook -i inventory.ini update_dns_resolvers.yml
```

### Option 2: Switch to DHCP-Managed DNS (Recommended)

```bash
ansible-playbook -i inventory.ini update_dns_resolvers.yml -e "use_dhcp_dns=true"
```

### Test on a Single Host First

```bash
ansible-playbook -i inventory.ini update_dns_resolvers.yml --limit testhost.example.com
```

### Check What Would Change (Dry Run)

```bash
ansible-playbook -i inventory.ini update_dns_resolvers.yml --check --diff
```

## Recommendations

### For Proxmox Templates

Since you're using reserved DHCP, I recommend:

1. **Set templates to use DHCP for DNS** - Let DHCP push DNS configuration
2. **Configure your UniFi DHCP server** to provide:
   - DNS server: 10.20.10.1
   - Search domain: tanx95.us
3. **Update existing systems** using this playbook with `use_dhcp_dns=true`

This approach means:
- ✅ Future DNS changes only require updating your UniFi DHCP server
- ✅ All VMs/containers get consistent DNS configuration automatically
- ✅ Reserved IPs still give you predictable addressing
- ✅ No need to manually configure DNS when spinning up new instances

### For Proxmox LXC/VM Creation

When Proxmox prompts for DNS during VM/container creation:
- Leave DNS server field **empty** or set to "auto"
- Ensure the network is configured for DHCP
- The system will get DNS from your DHCP reservation

## Verifying Changes

After running the playbook, verify DNS configuration:

```bash
# Check current DNS servers
ansible all -i inventory.ini -m shell -a "cat /etc/resolv.conf"

# Test DNS resolution
ansible all -i inventory.ini -m shell -a "nslookup google.com"

# Check systemd-resolved status (if applicable)
ansible all -i inventory.ini -m shell -a "systemd-resolve --status"
```

## Rollback

If needed, you can rollback using the backup:

```bash
ansible all -i inventory.ini -m shell -a "ls -la /etc/resolv.conf.backup.*"
ansible all -i inventory.ini -m copy -a "src=/etc/resolv.conf.backup.TIMESTAMP dest=/etc/resolv.conf remote_src=yes"
```

## Customization

Edit variables in the playbook:

```yaml
vars:
  old_dns_servers:
    - "10.20.111.49"
    - "10.20.10.33"
    - "10.20.10.34"
  new_dns_server: "10.20.10.1"
  search_domain: "tanx95.us"  # Your default search domain
  use_dhcp_dns: false  # Set to true to use DHCP for DNS
```

## Notes

- The playbook handles multiple Linux distributions and configuration methods
- Handlers automatically restart necessary services
- Existing DNS configurations are backed up with timestamps
- Safe to run multiple times (idempotent)
