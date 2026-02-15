output "vpc_id" {
  description = "The ID of the VPC"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = local.public_subnet_ids
}

output "instance_id" {
  description = "The ID of the Admin Server EC2 instance"
  value       = aws_instance.admin_server.id
}

output "public_ip" {
  description = "The public IP address of the Admin Server EC2 instance"
  value       = var.public_ip_enabled ? aws_instance.admin_server.public_ip : "NOT_ENABLED"
}

output "session_manager_connect_command" {
  description = "Command to connect to the Admin Server via AWS Systems Manager Session Manager (no EIC/SSH required)"
  value       = "aws ssm start-session --target ${aws_instance.admin_server.id} --region ${var.aws_region}"
}
