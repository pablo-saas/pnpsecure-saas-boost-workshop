module "vpc" {
  source   = "./modules/vpc"
  app_name = var.app_name
  vpc_cidr = "10.100.0.0/16"

  use_existing_vpc = false
}

locals {
  dbname      = "dbname"
  db_username = "dbuser"
}

module "db_instance" {
  source               = "terraform-aws-modules/rds/aws"
  version              = "6.5.1"
  identifier           = var.app_name
  engine               = "postgres"
  engine_version       = "13.14"
  family               = "postgres13"
  major_engine_version = "13"
  instance_class       = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = local.dbname
  username = local.db_username
  port     = "5432"

  manage_master_user_password = true

  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.security_group.security_group_id]

  create_cloudwatch_log_group = true

  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    }
  ]
}

module "security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "${var.app_name}-db"
  vpc_id = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]
}

module "ecs" {
  source   = "./modules/ecs"
  app_name = var.app_name

  vpc_id          = module.vpc.vpc_id
  vpc_cidr_blocks = module.vpc.vpc_cidr_block
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets

  db_host            = module.db_instance.db_instance_address
  db_port            = module.db_instance.db_instance_port
  dbname             = local.dbname
  db_username        = local.db_username
  db_user_secret_arn = module.db_instance.db_instance_master_user_secret_arn
}

module "cicd" {
  source = "./modules/cicd"
  app_name = var.app_name
}