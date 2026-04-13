#!/bin/bash
# Usage: run-workload.sh <git-url> [branch]
# Clones a workload repo, copies it to the NameNode, and runs workload.sh there.
set -euo pipefail

# Source shared utilities
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

WORKLOAD_URL="${1:?Usage: run-workload.sh <git-url> [branch]}"
BRANCH="${2:-main}"
WORKLOAD_DIR="/tmp/workload-$(date +%s)"

check_required_commands "terraform" "git" "scp" "ssh"

cd "${TERRAFORM_DIR}"

NAMENODE_IP=$(terraform output -raw namenode_public_ip) || {
  echo "ERROR: Failed to read namenode_public_ip from Terraform outputs."
  exit 1
}
KEY_PATH=$(terraform output -raw private_key_path) || {
  echo "ERROR: Failed to read private_key_path from Terraform outputs."
  exit 1
}

if [[ ! -f "${KEY_PATH}" ]]; then
  echo "ERROR: SSH key file not found at ${KEY_PATH}"
  exit 1
fi

mkdir -p "${SSH_DIR}"
touch "${KNOWN_HOSTS_FILE}"
chmod 700 "${SSH_DIR}" 2>/dev/null || true
chmod 600 "${KNOWN_HOSTS_FILE}"
ensure_known_host "${NAMENODE_IP}"

SSH_OPTS=(-i "${KEY_PATH}")

print_section "Cloning workload from ${WORKLOAD_URL} (branch: ${BRANCH})"
git clone --branch "${BRANCH}" --depth 1 "${WORKLOAD_URL}" "${WORKLOAD_DIR}"

# Validate workload.sh exists before proceeding
if [[ ! -f "${WORKLOAD_DIR}/workload.sh" ]]; then
  echo ""
  echo "ERROR: workload.sh not found in ${WORKLOAD_URL} (branch: ${BRANCH})"
  echo ""
  echo "The cloned repository must contain a 'workload.sh' script at the root."
  echo "Repository contents:"
  ls -la "${WORKLOAD_DIR}" | head -20
  echo ""
  rm -rf "${WORKLOAD_DIR}"
  exit 1
fi

if [[ ! -x "${WORKLOAD_DIR}/workload.sh" ]]; then
  chmod +x "${WORKLOAD_DIR}/workload.sh"
  echo "Note: Made workload.sh executable"
fi

print_section "Copying workload to NameNode (${NAMENODE_IP})"
scp "${SSH_OPTS[@]}" -r "${WORKLOAD_DIR}" "ec2-user@${NAMENODE_IP}:~/workload"

print_section "Submitting workload"
ssh "${SSH_OPTS[@]}" "ec2-user@${NAMENODE_IP}" \
  "cd ~/workload && bash workload.sh"

echo ""
print_banner "Workload completed successfully"
rm -rf "${WORKLOAD_DIR}"
