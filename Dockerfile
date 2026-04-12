FROM amazonlinux:2023

# System packages
RUN dnf update -y && dnf install -y \
    python3 \
    python3-pip \
    git \
    curl \
    unzip \
    openssh-clients \
    jq \
    awscli \
    tar \
    gzip \
    && dnf clean all

# Terraform
ARG TERRAFORM_VERSION=1.8.5
RUN curl -fsSL \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
      -o /tmp/terraform.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip \
    && terraform version

# Ansible + AWS SDK for Python (boto3 used by some Ansible modules)
ARG ANSIBLE_VERSION=9.5.1
RUN pip3 install --no-cache-dir \
    "ansible==${ANSIBLE_VERSION}" \
    boto3 \
    botocore

WORKDIR /workspace
COPY . /workspace

RUN chmod +x /workspace/scripts/*.sh \
             /workspace/ansible/inventory/generate_inventory.sh

ENTRYPOINT ["/workspace/scripts/entrypoint.sh"]
