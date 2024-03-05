locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  vpc_creation_count = var.use_existing_vpc ? 0 : 1
}

module "vpc" {
  count = local.vpc_creation_count

  source = "terraform-aws-modules/vpc/aws"

  name = "${var.app_name}-vpc"
  cidr = var.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 4)]
  database_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 8)]

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true
  single_nat_gateway     = false

  enable_dns_hostnames = true

  public_subnet_tags = {
    "Name" = "${var.app_name}-public-subnet"
  }

  private_subnet_tags = {
    "Name" = "${var.app_name}-private-subnet"
  }

  database_subnet_tags = {
    "Name" = "${var.app_name}-database-subnet"
  }
}

module "endpoints" {
  count = local.vpc_creation_count

  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  vpc_id = module.vpc[0].vpc_id

  create_security_group      = true
  security_group_name_prefix = "${var.app_name}-vpce-"
  security_group_description = "VPC endpoint security group"
  security_group_rules       = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc[0].vpc_cidr_block]
    }
  }

  endpoints = {
    s3 = {
      service = "s3"
      tags    = { Name = "s3-vpc-endpoint" }
    }
  }
}

data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
  count = local.vpc_creation_count

  statement {
    effect    = "Deny"
    actions   = ["dynamodb:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpc"

      values = [module.vpc[0].vpc_id]
    }
  }
}

data "aws_iam_policy_document" "generic_endpoint_policy" {
  count = local.vpc_creation_count

  statement {
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpc"

      values = [module.vpc[0].vpc_id]
    }
  }
}