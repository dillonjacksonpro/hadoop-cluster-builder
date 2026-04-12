#!/bin/bash
set -euo pipefail

# Source shared utilities
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

cd "${TERRAFORM_DIR}"

validate_prerequisites

print_banner "Provisioning AWS infrastructure with Terraform"

print_section "Initializing Terraform"
terraform init -input=false

print_section "Validating Terraform configuration"
validate_terraform_config

print_section "Planning infrastructure"
terraform plan -input=false -out=tfplan

if [[ "${CLUSTER_DRY_RUN:-false}" == "true" ]]; then
  print_section "DRY RUN: Skipping terraform apply"
  echo ""
  echo "To apply the above plan, run from the terraform directory:"
  echo "  terraform apply -input=false -auto-approve tfplan"
  echo ""
  print_banner "Dry-run completed successfully"
  exit 0
fi

print_section "Applying infrastructure"
terraform apply -input=false -auto-approve tfplan

print_section "Infrastructure provisioned"
terraform output
