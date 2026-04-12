#!/bin/bash
# Host-side launcher: builds the Docker image and runs the container.
# AWS credentials are read from your shell environment.
#
# Usage:
#   bash run.sh                          # use default cluster_size (3)
#   CLUSTER_SIZE=1 bash run.sh           # single-node cluster
#   CLUSTER_SIZE=5 bash run.sh           # 1 NameNode + 4 DataNodes
set -euo pipefail

IMAGE_NAME="hadoop-cluster-builder"

echo "=== Building Docker image: ${IMAGE_NAME} ==="
docker build -t "${IMAGE_NAME}" .

echo ""
echo "=== Starting Hadoop cluster builder container ==="
echo "    Cluster size: ${CLUSTER_SIZE:-3}"
echo ""

docker run -it --rm \
  -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}" \
  -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}" \
  -e AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-}" \
  -e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}" \
  -e TF_VAR_cluster_size="${CLUSTER_SIZE:-3}" \
  "${IMAGE_NAME}"
