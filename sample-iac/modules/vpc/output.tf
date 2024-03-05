output "azs" {
  value = local.azs
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = var.use_existing_vpc ? var.vpc_id : module.vpc[0].vpc_id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = var.use_existing_vpc ? data.aws_vpc.vpc[0].arn : module.vpc[0].vpc_arn
}

output "vpc_cidr_block" {
  value = var.use_existing_vpc ? data.aws_vpc.vpc[0].cidr_block : module.vpc[0].vpc_cidr_block
}

output "default_security_group_id" {
  value = var.use_existing_vpc ? data.aws_security_group.vpc_default[0].id : module.vpc[0].default_security_group_id
}

output "public_subnets" {
  value =var.use_existing_vpc ? var.public_subnets : module.vpc[0].public_subnets
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = var.use_existing_vpc ? var.private_subnets : module.vpc[0].private_subnets
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = var.use_existing_vpc ? [for s in data.aws_subnet.private_subnets : s.arn] : module.vpc[0].private_subnet_arns
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = var.use_existing_vpc ? [for s in data.aws_subnet.private_subnets : s.cidr_block] : module.vpc[0].private_subnets_cidr_blocks
}

output "database_subnet_group" {
  description = ""
  value = module.vpc[0].database_subnet_group
}
