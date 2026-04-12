#!/bin/bash
set -euo pipefail

# Source shared utilities
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

cd "${ANSIBLE_DIR}"

print_banner "Configuring Hadoop cluster with Ansible"

ansible-playbook site.yml \
  --inventory /workspace/ansible/hosts.ini \
  -v

echo ""
print_section "Hadoop cluster configuration complete"
