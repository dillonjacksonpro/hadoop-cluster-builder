#!/bin/bash
# Local launcher: provisions with Terraform, configures with Ansible,
# and opens an interactive shell. AWS credentials are read from your shell environment.
#
# Usage:
#   bash run.sh                          # use default cluster_size (3)
#   CLUSTER_SIZE=1 bash run.sh           # single-node cluster
#   CLUSTER_SIZE=5 bash run.sh           # 1 NameNode + 4 DataNodes
#   bash run.sh --dry-run                # terraform plan only
#   SKIP_PREFLIGHT=true bash run.sh      # skip dependency bootstrap
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTRYPOINT_SCRIPT="${SCRIPT_DIR}/scripts/entrypoint.sh"
PREFLIGHT_SCRIPT="${SCRIPT_DIR}/scripts/preflight.sh"

export PATH="${HOME}/.local/bin:${PATH}"

if [[ ! -x "${ENTRYPOINT_SCRIPT}" ]]; then
  chmod +x "${ENTRYPOINT_SCRIPT}"
fi

if [[ ! -x "${PREFLIGHT_SCRIPT}" ]]; then
  chmod +x "${PREFLIGHT_SCRIPT}"
fi

echo ""
echo "=== Starting Hadoop cluster builder ==="
echo "    Cluster size: ${CLUSTER_SIZE:-3}"
echo ""

export TF_VAR_cluster_size="${CLUSTER_SIZE:-3}"

if [[ "${SKIP_PREFLIGHT:-false}" != "true" ]]; then
  bash "${PREFLIGHT_SCRIPT}"
fi

bash "${ENTRYPOINT_SCRIPT}" "$@"
