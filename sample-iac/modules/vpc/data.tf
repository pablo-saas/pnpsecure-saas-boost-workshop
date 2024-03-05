data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  existing_vpc_count = var.use_existing_vpc ? 1 : 0
}

data "aws_vpc" "vpc" {
  count = local.existing_vpc_count
  id = var.vpc_id
}

data "aws_security_group" "vpc_default" {
  count = local.existing_vpc_count

  vpc_id = var.vpc_id

  filter {
    name   = "group-name"
    values = ["default"]
  }
}

data "aws_subnet" "private_subnets" {
  for_each = toset(var.private_subnets)
  id = each.value
}

data "aws_subnet" "database_subnets" {
  for_each = toset(var.database_subnets)
  id = each.value
}