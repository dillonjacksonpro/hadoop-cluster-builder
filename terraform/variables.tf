variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "hadoop-lab"
}

variable "cluster_size" {
  description = "Total number of nodes. 1 = single node running both NameNode and DataNode. N = 1 NameNode + (N-1) DataNodes."
  type        = number
  default     = 3

  validation {
    condition     = var.cluster_size >= 1 && var.cluster_size <= 10
    error_message = "cluster_size must be between 1 and 10."
  }
}

variable "instance_type" {
  description = "EC2 instance type for DataNodes"
  type        = string
  default     = "t3.medium"
}

variable "namenode_type" {
  description = "EC2 instance type for the NameNode (also used when cluster_size = 1)"
  type        = string
  default     = "t3.large"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "key_name" {
  description = "Name for the EC2 key pair created by Terraform"
  type        = string
  default     = "hadoop-lab-key"
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to access NameNode SSH and web UIs. Restrict this for safer deployments."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
