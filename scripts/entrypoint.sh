#!/bin/bash
set -euo pipefail

# Source shared utilities
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

WORKSPACE="${PROJECT_ROOT}"

# Parse command-line arguments
CLUSTER_DRY_RUN="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      CLUSTER_DRY_RUN="true"
      shift
      ;;
    *)
      echo "ERROR: Unknown argument: $1"
      echo "Usage: entrypoint.sh [--dry-run]"
      exit 1
      ;;
  esac
done

# Export for child scripts
export CLUSTER_DRY_RUN

# ── Cleanup function — called on any exit ────────────────────────────────────
cleanup() {
  local exit_code=$?
  echo ""
  # Only destroy if not in dry-run mode
  if [[ "${CLUSTER_DRY_RUN:-false}" == "true" ]]; then
    print_banner "Exiting — dry-run mode (no resources to destroy)"
  else
    print_banner "Exiting — destroying AWS infrastructure"
    bash "${SCRIPTS_DIR}/destroy.sh" || true
  fi
  exit "${exit_code}"
}

# Trap EXIT, TERM, and INT so cleanup fires under all conditions:
#   - Normal shell exit (user types 'exit' or Ctrl+D)
#   - Process termination (SIGTERM)
#   - Ctrl+C (SIGINT)
trap cleanup EXIT TERM INT

# ── Step 1: Provision infrastructure ─────────────────────────────────────────
if [[ "${CLUSTER_DRY_RUN}" == "true" ]]; then
  print_banner "DRY RUN MODE: Planning infrastructure (not applying)"
else
  print_banner "Provisioning AWS infrastructure"
fi
bash "${SCRIPTS_DIR}/provision.sh"

# Skip remaining steps in dry-run mode
if [[ "${CLUSTER_DRY_RUN}" == "true" ]]; then
  exit 0
fi

# ── Step 2: Generate Ansible inventory ───────────────────────────────────────
bash "${INVENTORY_SCRIPT}"

# ── Step 3: Configure Hadoop cluster ─────────────────────────────────────────
bash "${SCRIPTS_DIR}/configure.sh"

# ── Step 4: Print access information ─────────────────────────────────────────
cd "${TERRAFORM_DIR}"
NAMENODE_IP=$(terraform output -raw namenode_public_ip) || {
  echo "ERROR: Failed to read namenode_public_ip from Terraform outputs."
  exit 1
}
KEY_PATH=$(terraform output -raw private_key_path) || {
  echo "ERROR: Failed to read private_key_path from Terraform outputs."
  exit 1
}
CLUSTER_SIZE=$(terraform output -raw cluster_size) || {
  echo "ERROR: Failed to read cluster_size from Terraform outputs."
  exit 1
}

echo ""
print_banner "Hadoop Cluster Ready  (${CLUSTER_SIZE} node(s))"
echo ""
echo "  SSH to NameNode:"
echo "    ssh -i ${KEY_PATH} ec2-user@${NAMENODE_IP}"
echo ""
echo "  Web UIs (open in browser):"
echo "    HDFS NameNode:          http://${NAMENODE_IP}:9870"
echo "    YARN ResourceManager:   http://${NAMENODE_IP}:8088"
echo ""
echo "  Run a workload:"
echo "    ${SCRIPTS_DIR}/run-workload.sh <git-url> [branch]"
echo ""
echo "  Verify cluster health:"
echo "    ssh -i ${KEY_PATH} ec2-user@${NAMENODE_IP} 'sudo -u hadoop hdfs dfsadmin -report'"
echo ""
echo "  Type 'exit' or press Ctrl+D to destroy all resources and exit."
echo "============================================================"
echo ""

# ── Step 5: Interactive shell ─────────────────────────────────────────────────
# Run bash as a subprocess (not exec) so the EXIT trap above remains active.
# When the user exits the shell, this script resumes, reaches end-of-script,
# and the EXIT trap fires — calling destroy.sh.
/bin/bash
