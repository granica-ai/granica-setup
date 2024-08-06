output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "instance_id" {
  description = "The ID of the Admin Server EC2 instance"
  value       = aws_instance.admin_server.id
}

output "public_ip" {
  description = "The public IP address of the Admin Server EC2 instance"
  value = var.public_ip_enabled ? aws_instance.admin_server.public_ip : "NOT_ENABLED"
}
