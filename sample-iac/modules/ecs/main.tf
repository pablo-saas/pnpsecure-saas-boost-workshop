data "aws_caller_identity" "current" {}
data "aws_ecr_authorization_token" "this" {}
data "aws_region" "current" {}

locals {
  container_name = var.app_name
  container_port = 8080

  ecr_address = format(
    "%v.dkr.ecr.%v.amazonaws.com",
    data.aws_caller_identity.current.account_id,
    data.aws_region.current.name
  )
}

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.6.0"

  repository_force_delete     = true
  repository_name             = local.container_name
  repository_image_tag_mutability = "MUTABLE"
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        action = {
          type = "expire"
        }
        description  = "Delete all images except a handful of the newest images"
        rulePriority = 1
        selection    = {
          countNumber = 3
          countType   = "imageCountMoreThan"
          tagStatus   = "any"
        }
      }
    ]
  })
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.4.0"
  name = "${var.app_name}-ecs-service-alb"

  load_balancer_type    = "application"
  create_security_group = true
  subnets               = var.public_subnets
  vpc_id                = var.vpc_id

  security_group_rules = {
    ingress_all_http = {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      description = "Permit incoming HTTP requests from the internet"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Permit all outgoing requests to the internet"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  http_tcp_listeners = [
    {
      # * Setup a listener on port 80 and forward all HTTP
      # * traffic to target_groups[0] defined below which
      # * will eventually point to our "Hello World" app.
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      backend_port     = local.container_port
      backend_protocol = "HTTP"
      target_type      = "ip"
      health_check     = {
        enabled = true
        matcher = "200-499"
      }
    }
  ]
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 4.1.3"

  cluster_name = "${var.app_name}-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.app_name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "secrets_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      var.db_user_secret_arn
    ]
  }
}

resource "aws_iam_policy" "secrets_policy" {
  name = "${var.app_name}-secrets-policy"
  policy = data.aws_iam_policy_document.secrets_policy.json
}

resource "aws_iam_role_policy_attachment" "secrets_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.secrets_policy.arn
}

resource "aws_cloudwatch_log_group" "ecs_task_log_group" {
  name = "${var.app_name}-ecs-task-logs"
}

resource "aws_ecs_task_definition" "this" {
  family = "${var.app_name}-task-definitions"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      essential        = true,
      image            = "${module.ecr.repository_url}:latest",
      name             = local.container_name,
      portMappings     = [{ containerPort = local.container_port }],
      environment = [
        {
          name = "DB_HOST",
          value = var.db_host
        },
        {
          name = "DB_PORT",
          value = tostring(var.db_port)
        },
        {
          name = "DB_NAME",
          value = var.dbname
        }
      ]
      secrets = [
        {
          name = "DB_USER",
          valueFrom = "${var.db_user_secret_arn}:username::"
        },
        {
          name = "DB_PASSWORD",
          valueFrom = "${var.db_user_secret_arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_task_log_group.id,
          awslogs-region        = data.aws_region.current.name,
          awslogs-stream-prefix = "${var.app_name}-container-"
        }
      }
    }
  ])

  cpu    = 1024
  memory = 2048

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

module "ecs_task_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "${var.app_name}-ecs-service-security-group"
  vpc_id = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = var.vpc_cidr_blocks
    }
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "aws_ecs_service" "this" {
  cluster         = module.ecs.cluster_id
  desired_count   = 1
  launch_type     = "FARGATE"
  name            = var.app_name
  task_definition = aws_ecs_task_definition.this.arn

  lifecycle {
    ignore_changes = [desired_count]
  }

  load_balancer {
    container_name   = local.container_name
    container_port   = local.container_port
    target_group_arn = module.alb.target_group_arns[0]
  }

  network_configuration {
    security_groups = [module.ecs_task_security_group.security_group_id]
    subnets         = var.private_subnets
  }
}