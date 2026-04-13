#!/bin/bash
# Reads Terraform outputs and writes ansible/hosts.ini.
# Called automatically by entrypoint.sh after terraform apply.
set -euo pipefail

# Source shared utilities
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${script_dir}/scripts/lib.sh"

TERRAFORM_DIR="${TERRAFORM_DIR:-${PROJECT_ROOT}/terraform}"
INVENTORY_FILE="${ANSIBLE_DIR}/hosts.ini"

cd "${TERRAFORM_DIR}"

print_section "Generating Ansible inventory"

NAMENODE_IP=$(terraform output -raw namenode_public_ip)
KEY_PATH=$(terraform output -raw private_key_path)
SINGLE_NODE=$(terraform output -raw single_node)
HDFS_REPLICATION_FACTOR=$(terraform output -raw hdfs_replication_factor)
DATANODE_IPS_JSON=$(terraform output -json datanode_public_ips)

ensure_known_host "${NAMENODE_IP}"

{
  echo "[namenode]"
  echo "${NAMENODE_IP} ansible_user=ec2-user ansible_ssh_private_key_file=${KEY_PATH}"
  echo ""
  echo "[datanode]"

  if [[ "${SINGLE_NODE}" == "true" ]]; then
    # Single-node: NameNode also acts as DataNode
    echo "${NAMENODE_IP} ansible_user=ec2-user ansible_ssh_private_key_file=${KEY_PATH}"
  else
    # Multi-node: write each DataNode
    echo "${DATANODE_IPS_JSON}" | jq -r '.[]' | while read -r ip; do
      ensure_known_host "${ip}"
      echo "${ip} ansible_user=ec2-user ansible_ssh_private_key_file=${KEY_PATH}"
    done
  fi

  echo ""
  echo "[hadoop_cluster:children]"
  echo "namenode"
  echo "datanode"
  echo ""
  echo "[hadoop_cluster:vars]"
  echo "hdfs_replication_factor=${HDFS_REPLICATION_FACTOR}"
} > "${INVENTORY_FILE}"

sort -u "${KNOWN_HOSTS_FILE}" -o "${KNOWN_HOSTS_FILE}"

echo "Inventory written to ${INVENTORY_FILE}"
cat "${INVENTORY_FILE}"
