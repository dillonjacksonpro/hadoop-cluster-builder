output "namenode_public_ip" {
  description = "Public IP of the NameNode"
  value       = aws_instance.namenode.public_ip
}

output "namenode_private_ip" {
  description = "Private IP of the NameNode"
  value       = aws_instance.namenode.private_ip
}

output "namenode_public_dns" {
  description = "Public DNS of the NameNode"
  value       = aws_instance.namenode.public_dns
}

output "datanode_public_ips" {
  description = "Public IPs of all DataNodes (empty when cluster_size = 1)"
  value       = aws_instance.datanode[*].public_ip
}

output "datanode_private_ips" {
  description = "Private IPs of all DataNodes"
  value       = aws_instance.datanode[*].private_ip
}

output "datanode_public_dns" {
  description = "Public DNS of all DataNodes"
  value       = aws_instance.datanode[*].public_dns
}

output "private_key_path" {
  description = "Path to the SSH private key file"
  value       = local_file.private_key.filename
}

output "cluster_size" {
  description = "Total number of nodes in the cluster"
  value       = var.cluster_size
}

output "hdfs_replication_factor" {
  description = "HDFS replication factor used for this cluster"
  value       = local.hdfs_replication_factor
}

output "single_node" {
  description = "True when cluster_size = 1 (NameNode and DataNode on the same host)"
  value       = local.single_node
}

output "ssh_command" {
  description = "SSH command to access the NameNode"
  value       = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.namenode.public_ip}"
}

output "hdfs_ui" {
  description = "URL for the HDFS NameNode web UI"
  value       = "http://${aws_instance.namenode.public_ip}:9870"
}

output "yarn_ui" {
  description = "URL for the YARN ResourceManager web UI"
  value       = "http://${aws_instance.namenode.public_ip}:8088"
}
