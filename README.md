# Hadoop Cluster Builder

Provisions a Hadoop cluster on AWS using Terraform and Ansible directly from your shell.

## Prerequisites

- Bash
- curl and unzip (needed for user-local fallback installs)
- AWS credentials (access key, secret key, session token if using a lab account)

On startup, `run.sh` executes `scripts/preflight.sh` and installs missing dependencies that were previously provided by Docker (Terraform, Ansible, AWS CLI, jq, and support tools).

- If root/sudo is available: installs via `apt`, `dnf`, or `yum`
- If root/sudo is not available: installs supported tools to `~/.local/bin`

## Quick Start

```bash
# Clone the repo
git clone <this-repo> hadoop-cluster-builder
cd hadoop-cluster-builder

# Set your AWS credentials (or use ~/.aws/credentials or an instance role)
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...       # if using temporary/lab credentials
export AWS_DEFAULT_REGION=us-east-1

# Run (default: 3-node cluster)
bash run.sh

# Optional: skip auto-install/bootstrap preflight
SKIP_PREFLIGHT=true bash run.sh
```

That command will:
1. Provision a VPC, security groups, and EC2 instances via Terraform
2. Configure Hadoop (HDFS + YARN) across all nodes via Ansible
3. Drop you into an interactive shell with the cluster ready to use

When you type `exit` (or press Ctrl+D), all AWS resources are destroyed automatically.

## Cluster Size

Control the number of nodes with the `CLUSTER_SIZE` environment variable:

| `CLUSTER_SIZE` | Topology | HDFS replication |
|---|---|---|
| `1` | 1 node — NameNode + DataNode combined | 1 |
| `2` | 1 NameNode + 1 DataNode | 2 |
| `3` (default) | 1 NameNode + 2 DataNodes | 3 |
| `4`–`10` | 1 NameNode + (N-1) DataNodes | 3 |

```bash
CLUSTER_SIZE=1 bash run.sh    # minimal single-node cluster
CLUSTER_SIZE=5 bash run.sh    # 1 NameNode + 4 DataNodes
```

## Dry Run

To preview Terraform changes without applying:

```bash
bash run.sh --dry-run
```

## Instance Types

| Role | Default type | RAM |
|---|---|---|
| NameNode | `t3.large` | 8 GB |
| DataNode | `t3.medium` | 4 GB |

Override via `terraform.tfvars` (see `terraform/terraform.tfvars.example`).

`terraform.tfvars` is optional. Defaults are used if the file is absent.
To customize settings, copy and edit the example:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

## Security Notes

- By default, NameNode SSH and web UIs are reachable from anywhere (`0.0.0.0/0`) for quick lab setup.
- For safer usage, restrict access with `admin_cidr_blocks` in `terraform/terraform.tfvars`.

```hcl
admin_cidr_blocks = ["203.0.113.10/32"]
```

- SSH host key checking is enabled for Ansible and workload execution. The tooling pre-populates `known_hosts` automatically during provisioning.

## Once Provisioned

Once provisioned, the launcher drops you into a shell. You can:

```bash
# SSH to the NameNode
ssh -i ./terraform/hadoop_key.pem ec2-user@<namenode-ip>

# Check HDFS cluster status
ssh -i ./terraform/hadoop_key.pem ec2-user@<namenode-ip> \
    'sudo -u hadoop hdfs dfsadmin -report'

# Check YARN nodes
ssh -i ./terraform/hadoop_key.pem ec2-user@<namenode-ip> \
    'sudo -u hadoop yarn node -list'

# Run a workload from a git repo
./scripts/run-workload.sh https://github.com/org/my-workload.git
```

Web UIs (open in your browser — IPs printed at startup):
- **HDFS NameNode UI**: `http://<namenode-ip>:9870`
- **YARN ResourceManager UI**: `http://<namenode-ip>:8088`

## Cleanup

Just exit the shell:

```bash
exit
```

Terraform destroy runs automatically. All EC2 instances, the VPC, security groups, key pairs, and IAM roles are removed. Verify in the AWS console that no resources remain under the `hadoop-lab` tag.

If cleanup fails (e.g., credentials expired), run manually:

```bash
cd ./terraform && terraform destroy
```

## Architecture

```
Local shell
├── Terraform — provisions AWS infrastructure
│   ├── VPC + public subnet
│   ├── EC2: 1 NameNode (t3.large)
│   ├── EC2: N-1 DataNodes (t3.medium)
│   ├── Security groups (internal cluster + external SSH/UI)
│   └── IAM instance profile (SSM access)
└── Ansible — configures Hadoop
    ├── Java 11 (Amazon Corretto)
    ├── Hadoop 3.3.6 (HDFS + YARN + MapReduce)
    └── Inter-node SSH keys for Hadoop daemon management
```

## Workloads

See [workloads/README.md](workloads/README.md) for the workload convention and an example `workload.sh`.
