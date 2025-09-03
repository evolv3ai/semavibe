#!/usr/bin/env bash
set -euo pipefail

# Build inventory (returns path)
cd "$(dirname "$0")"
inv_path=$(./make_inventory.sh)

# Now run the Ansible playbook from repo root's ansible folder
# Resolve repo root (two levels up from here)
repo_root="$(cd ../.. && pwd)"
cd "$repo_root/ansible"

# Use the generated inventory path; Ansible SSH key/user come from group_vars/all.yml
ansible-playbook -i "$inv_path" site.yml
