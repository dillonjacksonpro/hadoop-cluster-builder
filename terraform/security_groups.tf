# Internal security group — allows all traffic between cluster nodes
resource "aws_security_group" "internal" {
  name        = "${var.cluster_name}-internal"
  description = "Allow all traffic between Hadoop cluster nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "All intra-cluster traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.cluster_name}-sg-internal"
    Cluster = var.cluster_name
  }
}

# External security group — SSH, HDFS NameNode UI, YARN ResourceManager UI
resource "aws_security_group" "external" {
  name        = "${var.cluster_name}-external"
  description = "SSH and Hadoop web UIs"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "HDFS NameNode Web UI"
    from_port   = 9870
    to_port     = 9870
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "YARN ResourceManager Web UI"
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.cluster_name}-sg-external"
    Cluster = var.cluster_name
  }
}
