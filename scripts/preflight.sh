#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

export PATH="${HOME}/.local/bin:${PATH}"

TERRAFORM_VERSION="${TERRAFORM_VERSION:-1.8.5}"
JQ_VERSION="${JQ_VERSION:-1.7.1}"

get_pkg_manager() {
  if command -v apt-get > /dev/null 2>&1; then
    echo "apt"
    return
  fi
  if command -v dnf > /dev/null 2>&1; then
    echo "dnf"
    return
  fi
  if command -v yum > /dev/null 2>&1; then
    echo "yum"
    return
  fi
  echo "none"
}

get_priv_prefix() {
  if [[ "${EUID}" -eq 0 ]]; then
    echo ""
    return
  fi
  if command -v sudo > /dev/null 2>&1; then
    echo "sudo"
    return
  fi
  echo "none"
}

cmd_missing() {
  ! command -v "$1" > /dev/null 2>&1
}

install_root_packages() {
  local pkg_manager="$1"
  local priv_prefix="$2"
  local -a packages=()

  if [[ $# -gt 2 ]]; then
    packages=("${@:3}")
  fi

  if [[ "${pkg_manager}" == "none" ]] || [[ "${priv_prefix}" == "none" ]] || [[ ${#packages[@]} -eq 0 ]]; then
    return 0
  fi

  print_section "Installing missing system packages (${pkg_manager})"
  case "${pkg_manager}" in
    apt)
      ${priv_prefix} apt-get update -y
      ${priv_prefix} apt-get install -y "${packages[@]}"
      ;;
    dnf)
      ${priv_prefix} dnf install -y "${packages[@]}"
      ;;
    yum)
      ${priv_prefix} yum install -y "${packages[@]}"
      ;;
  esac
}

install_terraform_user() {
  if ! cmd_missing terraform; then
    return 0
  fi
  if cmd_missing curl || cmd_missing unzip; then
    return 0
  fi

  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "WARNING: Unsupported architecture for Terraform auto-install: ${arch}"
      return 0
      ;;
  esac

  print_section "Installing Terraform ${TERRAFORM_VERSION} to ${HOME}/.local/bin"
  mkdir -p "${HOME}/.local/bin"

  local tmp_zip
  tmp_zip="$(mktemp /tmp/terraform.XXXXXX.zip)"

  curl -fsSL \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${arch}.zip" \
    -o "${tmp_zip}"
  unzip -qo "${tmp_zip}" -d "${HOME}/.local/bin"
  chmod +x "${HOME}/.local/bin/terraform"
  rm -f "${tmp_zip}"
}

install_jq_user() {
  if ! cmd_missing jq; then
    return 0
  fi
  if cmd_missing curl; then
    return 0
  fi

  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) arch="jq-linux-amd64" ;;
    aarch64|arm64) arch="jq-linux-arm64" ;;
    *)
      echo "WARNING: Unsupported architecture for jq auto-install: ${arch}"
      return 0
      ;;
  esac

  print_section "Installing jq ${JQ_VERSION} to ${HOME}/.local/bin"
  mkdir -p "${HOME}/.local/bin"
  curl -fsSL \
    "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/${arch}" \
    -o "${HOME}/.local/bin/jq"
  chmod +x "${HOME}/.local/bin/jq"
}

install_python_tools_user() {
  if cmd_missing python3; then
    return 0
  fi

  if cmd_missing pip3; then
    python3 -m ensurepip --upgrade > /dev/null 2>&1 || true
  fi

  if cmd_missing pip3; then
    return 0
  fi

  if cmd_missing aws || cmd_missing ansible-playbook; then
    local python_version
    python_version="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"

    local aws_spec
    local ansible_spec
    aws_spec="${AWSCLI_PIP_SPEC:-awscli}"
    ansible_spec="${ANSIBLE_PIP_SPEC:-ansible}"

    if [[ "${python_version}" == "3.6" ]] || [[ "${python_version}" == "3.7" ]]; then
      aws_spec="${AWSCLI_PIP_SPEC:-awscli<1.32}"
      ansible_spec="${ANSIBLE_PIP_SPEC:-ansible==2.9.27}"
      print_section "Installing Python 3.7-compatible tooling to user site"
      # Older Python environments often require a legacy packaging stack.
      python3 -m pip install --user \
        "pip<23.3" \
        "setuptools<58" \
        "wheel<0.38" \
        "typing_extensions<4.0" \
        "importlib_metadata<5" || true
    else
      print_section "Installing Python tooling (awscli, ansible, boto3, botocore) to user site"
    fi

    python3 -m pip install --user "${aws_spec}" boto3 botocore

    if cmd_missing ansible-playbook; then
      if ! python3 -m pip install --user "${ansible_spec}"; then
        if [[ "${python_version}" == "3.6" ]] || [[ "${python_version}" == "3.7" ]]; then
          print_section "Retrying ansible install with fallback version for older Python"
          python3 -m pip install --user "ansible==2.8.20" || true
        fi
      fi
    fi
  fi
}

print_banner "Preflight: dependency bootstrap"

pkg_manager="$(get_pkg_manager)"
priv_prefix="$(get_priv_prefix)"

if [[ "${priv_prefix}" == "none" ]]; then
  echo "INFO: No root/sudo detected. Falling back to user-local installs where possible."
fi

declare -a root_packages=()

if cmd_missing python3; then
  root_packages+=("python3")
fi
if cmd_missing pip3; then
  root_packages+=("python3-pip")
fi
if cmd_missing git; then
  root_packages+=("git")
fi
if cmd_missing curl; then
  root_packages+=("curl")
fi
if cmd_missing unzip; then
  root_packages+=("unzip")
fi
if cmd_missing tar; then
  root_packages+=("tar")
fi
if cmd_missing gzip; then
  root_packages+=("gzip")
fi
if cmd_missing ssh-keyscan; then
  if [[ "${pkg_manager}" == "apt" ]]; then
    root_packages+=("openssh-client")
  else
    root_packages+=("openssh-clients")
  fi
fi

if [[ ${#root_packages[@]} -gt 0 ]]; then
  install_root_packages "${pkg_manager}" "${priv_prefix}" "${root_packages[@]}" || \
    echo "WARNING: Package manager install step failed; continuing with user-local fallback."
fi

install_terraform_user || true
install_jq_user || true
install_python_tools_user || true

required=(terraform ansible-playbook aws jq ssh-keyscan git curl unzip tar gzip)
missing=()
for cmd in "${required[@]}"; do
  if cmd_missing "${cmd}"; then
    missing+=("${cmd}")
  fi
done

echo ""
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "ERROR: Missing required dependencies after preflight bootstrap:"
  printf "  - %s\n" "${missing[@]}"
  echo ""
  echo "Ensure ${HOME}/.local/bin is on PATH and install missing system tools manually if needed."
  exit 1
fi

echo "Preflight complete: all required dependencies are available."