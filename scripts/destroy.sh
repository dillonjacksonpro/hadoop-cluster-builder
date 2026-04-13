#!/bin/bash
# Called by the EXIT trap in entrypoint.sh.
# Best-effort: do not use set -e — we want to report errors without crashing.

# Source shared utilities (without aborting on error)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || script_dir="$(pwd)/scripts"
if ! source "${script_dir}/lib.sh" 2>/dev/null; then
  print_banner() {
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
  }
  print_section() {
    echo ""
    echo "=== $1 ==="
  }
fi

PROJECT_ROOT="$(cd "${script_dir}/.." 2>/dev/null && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-${PROJECT_ROOT}/terraform}"

cd "${TERRAFORM_DIR}" 2>/dev/null || {
  echo "WARNING: Could not cd to ${TERRAFORM_DIR}"
  exit 0
}

if [[ ! -f terraform.tfstate ]]; then
  echo "=== No Terraform state found — nothing to destroy ==="
  exit 0
fi

echo ""
print_banner "Destroying AWS infrastructure...(This may take 2-3 minutes)"

# Retrieve the cluster name from Terraform state for the warning message
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null) || CLUSTER_NAME="hadoop-lab"

# Retry logic with exponential backoff: 3 attempts (5s, 10s, 20s delays)
TERRAFORM_DESTROY_RETRIES=3
RETRY_DELAYS=(5 10 20)
ATTEMPT=1

while [[ ${ATTEMPT} -le ${TERRAFORM_DESTROY_RETRIES} ]]; do
  print_section "Destroy attempt ${ATTEMPT} of ${TERRAFORM_DESTROY_RETRIES}"
  if terraform destroy -auto-approve -input=false; then
    echo ""
    echo "=== Infrastructure destroyed successfully ==="
    break
  else
    DESTROY_EXIT_CODE=$?
    if [[ ${ATTEMPT} -lt ${TERRAFORM_DESTROY_RETRIES} ]]; then
      DELAY=${RETRY_DELAYS[$((ATTEMPT - 1))]}
      echo "WARNING: terraform destroy failed (exit code ${DESTROY_EXIT_CODE}). Retrying in ${DELAY}s..."
      sleep ${DELAY}
    fi
    ATTEMPT=$((ATTEMPT + 1))
  fi
done

if [[ ${ATTEMPT} -gt ${TERRAFORM_DESTROY_RETRIES} ]]; then
  echo ""
  echo "WARNING: terraform destroy failed after ${TERRAFORM_DESTROY_RETRIES} attempts."
  echo "Check the AWS console for any orphaned resources tagged with Cluster=${CLUSTER_NAME}"
  echo "You can re-run: cd ${TERRAFORM_DIR} && terraform destroy"
fi

echo ""
echo "=== Cleanup complete ==="
