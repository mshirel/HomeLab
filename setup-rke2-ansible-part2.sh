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

