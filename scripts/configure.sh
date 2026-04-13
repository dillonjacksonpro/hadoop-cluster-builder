#!/bin/bash
set -euo pipefail

# Source shared utilities
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

check_required_commands "ansible-playbook"

if [[ ! -f "${ANSIBLE_DIR}/hosts.ini" ]]; then
  echo "ERROR: Ansible inventory not found at ${ANSIBLE_DIR}/hosts.ini"
  echo "Run provisioning and inventory generation first."
  exit 1
fi

cd "${ANSIBLE_DIR}"

print_banner "Configuring Hadoop cluster with Ansible"

ansible-playbook site.yml \
  --inventory "${ANSIBLE_DIR}/hosts.ini" \
  -v

echo ""
print_section "Hadoop cluster configuration complete"
