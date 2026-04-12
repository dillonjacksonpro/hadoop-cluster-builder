#!/bin/bash
#
# Shared utilities for Hadoop Cluster Builder project
# Source this file in other scripts: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#

# ──────────────────────────────────────────────────────────────────────────────
# Directory and Path Constants
# ──────────────────────────────────────────────────────────────────────────────

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPTS_DIR")"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
INVENTORY_SCRIPT="$ANSIBLE_DIR/inventory/generate_inventory.sh"

# ──────────────────────────────────────────────────────────────────────────────
# Banner and Logging Functions
# ──────────────────────────────────────────────────────────────────────────────

# Print a formatted banner message
# Usage: print_banner "Message text"
print_banner() {
  local message="$1"
  echo "============================================================"
  echo "  ${message}"
  echo "============================================================"
}

# Print a section header (smaller than banner)
# Usage: print_section "Section title"
print_section() {
  local message="$1"
  echo ""
  echo "=== ${message} ==="
}

# ──────────────────────────────────────────────────────────────────────────────
# SSH and Known Hosts Management
# ──────────────────────────────────────────────────────────────────────────────

# Ensure IP address is in ~/.ssh/known_hosts
# Usage: ensure_known_host "1.2.3.4"
ensure_known_host() {
  local ip="$1"
  
  mkdir -p /root/.ssh
  touch /root/.ssh/known_hosts
  chmod 600 /root/.ssh/known_hosts
  
  # Check if already present
  if ssh-keygen -F "${ip}" > /dev/null 2>&1; then
    return 0
  fi
  
  # Add with ssh-keyscan, suppress errors (key scanning may fail on restricted networks)
  ssh-keyscan -H "${ip}" >> /root/.ssh/known_hosts 2>/dev/null || true
  
  # Dedup and sort the known_hosts file
  sort -u /root/.ssh/known_hosts -o /root/.ssh/known_hosts
}

# Ensure multiple IPs are in ~/.ssh/known_hosts
# Usage: ensure_known_hosts "1.2.3.4" "5.6.7.8" "9.10.11.12"
ensure_known_hosts() {
  for ip in "$@"; do
    ensure_known_host "$ip"
  done
}

# ──────────────────────────────────────────────────────────────────────────────
# Retry Logic
# ──────────────────────────────────────────────────────────────────────────────

# Run a command with exponential backoff retry
# Usage: run_command_with_retry 3 5 "some command with args"
# Args: max_attempts initial_delay_seconds command [command_args...]
run_command_with_retry() {
  local max_attempts="$1"
  local initial_delay="$2"
  shift 2
  local command=("$@")
  
  local attempt=1
  local delay="$initial_delay"
  
  while [[ $attempt -le $max_attempts ]]; do
    echo "[Attempt $attempt/$max_attempts] Running: ${command[*]}"
    
    if "${command[@]}"; then
      return 0
    fi
    
    local exit_code=$?
    
    if [[ $attempt -lt $max_attempts ]]; then
      echo "Command failed with exit code $exit_code. Retrying in ${delay}s..."
      sleep "$delay"
      # Double the delay for next attempt (exponential backoff)
      delay=$((delay * 2))
    else
      echo "Command failed after $max_attempts attempts."
      return "$exit_code"
    fi
    
    ((attempt++))
  done
}

# ──────────────────────────────────────────────────────────────────────────────
# AWS Credential Validation
# ──────────────────────────────────────────────────────────────────────────────

# Validate that AWS credentials are available and valid
validate_aws_credentials() {
  if [[ -z "${AWS_DEFAULT_REGION:-}" && -z "${AWS_REGION:-}" ]]; then
    echo "ERROR: AWS_DEFAULT_REGION (or AWS_REGION) must be set."
    return 1
  fi

  if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    echo "ERROR: AWS_SECRET_ACCESS_KEY is required when AWS_ACCESS_KEY_ID is set."
    return 1
  fi

  if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -z "${AWS_PROFILE:-}" ]]; then
    if ! curl -sf --max-time 5 \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/ \
      > /dev/null 2>&1; then
      echo "ERROR: No AWS credentials found (env vars, AWS profile, or instance role)."
      return 1
    fi
  fi

  if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "ERROR: AWS credentials are invalid, expired, or missing required permissions."
    return 1
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Command Availability Checks
# ──────────────────────────────────────────────────────────────────────────────

# Check if a command/executable is available
# Usage: command_exists "terraform"
command_exists() {
  command -v "$1" > /dev/null 2>&1
}

# Verify that all required commands are installed
# Usage: check_required_commands "terraform" "ansible" "aws"
check_required_commands() {
  local missing=()
  
  for cmd in "$@"; do
    if ! command_exists "$cmd"; then
      missing+=("$cmd")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: The following required commands are not installed:"
    printf "  - %s\n" "${missing[@]}"
    return 1
  fi
  
  return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# Pre-Provisioning Validation
# ──────────────────────────────────────────────────────────────────────────────

# Validate all prerequisites before infrastructure provisioning
# Usage: validate_prerequisites
validate_prerequisites() {
  local has_errors=false
  
  print_banner "Validating prerequisites"
  
  # Check AWS credentials
  echo ""
  print_section "Checking AWS credentials"
  if ! validate_aws_credentials; then
    echo "ERROR: AWS credential validation failed"
    has_errors=true
  else
    echo "✓ AWS credentials validated"
  fi
  
  # Check required commands
  echo ""
  print_section "Checking required commands"
  if ! check_required_commands "terraform" "ansible" "aws" "jq" "ssh-keyscan"; then
    has_errors=true
  else
    echo "✓ All required commands available"
  fi
  
  echo ""
  if [[ "${has_errors}" == "true" ]]; then
    echo "ERROR: Pre-provisioning validation failed"
    return 1
  fi
  
  print_banner "Prerequisites validation completed successfully"
  return 0
}

# Validate Terraform configuration syntax after Terraform has been initialized
validate_terraform_config() {
  if [[ ! -d "${TERRAFORM_DIR}" ]]; then
    echo "ERROR: Terraform directory not found at ${TERRAFORM_DIR}"
    return 1
  fi
  
  cd "${TERRAFORM_DIR}"
  
  if ! terraform validate > /dev/null 2>&1; then
    echo "ERROR: Terraform configuration is invalid"
    terraform validate
    return 1
  fi
  
  return 0
}
