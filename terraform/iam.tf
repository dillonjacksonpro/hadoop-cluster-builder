data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "hadoop" {
  name               = "${var.cluster_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Cluster = var.cluster_name
  }
}

# SSM access — allows fallback session manager access if SSH fails
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.hadoop.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "hadoop" {
  name = "${var.cluster_name}-profile"
  role = aws_iam_role.hadoop.name
}
