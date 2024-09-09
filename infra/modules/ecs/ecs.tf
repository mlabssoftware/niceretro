data "aws_vpc" "deployment_vpc" {
  id = var.vpc_id
}

resource "aws_security_group" "ecs_service" {
  vpc_id      = var.vpc_id
  name        = "${var.application_name}-ecs-service-sg"
  description = "Allow egress from container"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.deployment_vpc.cidr_block]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.application_name}-ecs-service-sg"
    Environment = var.environment
  }
}

data "aws_secretsmanager_secret_version" "deployment_secrets_version" {
  secret_id = var.secret_name
}

locals {
  secret_keys = keys(jsondecode(data.aws_secretsmanager_secret_version.deployment_secrets_version.secret_string))
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_task_execution_role_${var.application_name}"
  # assume_role_policy = file("${path.module}/policies/ecs-task-execution-role.json")

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : ["ecs-tasks.amazonaws.com", "scheduler.amazonaws.com"]
        },
        "Action" : "sts:AssumeRole"
      }
  ] })
}

//ecs_execution_role_policy

resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name = "ecs_service_role_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : concat([
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ], var.execution_role_aditional_permissions),
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "execute-api:ManageConnections"
        ],
        "Resource" : "arn:aws:execute-api:*:*:**/@connections/*"
      }
    ]
  })

  role = aws_iam_role.ecs_execution_role.id
}

#Define as tasks para o ECS
resource "aws_ecs_task_definition" "task" {
  for_each = var.tasks

  family                   = "${var.application_name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.task_cpu
  memory                   = each.value.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name         = "${var.application_name}-${each.key}"
      image        = var.ecr_repository_url
      memory       = each.value.task_memory
      essential    = true
      entryPoint   = each.value.entrypoint
      networkMode  = "awsvpc"
      portMappings = []
      mountPoints  = []
      environment  = []
      secrets = [for s in local.secret_keys : {
        "name" : s,
        "valueFrom" : "${data.aws_secretsmanager_secret_version.deployment_secrets_version.arn}:${s}::"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "${var.application_name}-${each.key}"
          awslogs-region        = var.region
          awslogs-stream-prefix = "${var.application_name}-${each.key}"
        }
      }
    }
  ])
}

#Cria o cluster ECS
resource "aws_ecs_cluster" "cluster" {
  name = "${var.application_name}-ecs-cluster"
  tags = local.tags

}

# Lê todos os tasks criados 
data "aws_ecs_task_definition" "task" {
  for_each = var.tasks

  task_definition = aws_ecs_task_definition.task[each.key].family
}

#Cria o ECS Service
resource "aws_ecs_service" "task" {
  for_each = { for key, value in var.tasks : key => value if lookup(value, "create_service", false) == true }

  name                    = "${var.application_name}-${each.key}"
  task_definition         = "${aws_ecs_task_definition.task[each.key].family}:${max(aws_ecs_task_definition.task[each.key].revision, data.aws_ecs_task_definition.task[each.key].revision)}"
  desired_count           = lookup(each.value, "desired_count", 0)
  launch_type             = "FARGATE"
  cluster                 = aws_ecs_cluster.cluster.id
  depends_on              = [aws_iam_role_policy.ecs_service_role_policy]
  propagate_tags          = "SERVICE"
  enable_ecs_managed_tags = true

  network_configuration {
    security_groups  = [aws_security_group.ecs_service.id]
    subnets          = lookup(each.value, "assign_public_ip", true) ? var.public_subnet_ids : var.private_subnet_ids
    assign_public_ip = lookup(each.value, "assign_public_ip", true)
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }

  tags = {
    Name        = "${var.application_name}-${each.key}"
    Application = var.application_name
    Environment = var.environment
  }
}

#Cria o CW group
resource "aws_cloudwatch_log_group" "log_group" {
  for_each = var.tasks

  name              = "${var.application_name}-${each.key}"
  retention_in_days = lookup(each.value, "log_retention_days", 7)

  tags = {
    Environment = var.environment
    Application = var.application_name
    Name        = "${var.application_name}-${each.key}"
  }
}

#Cria o autoscaling para o ECS
resource "aws_appautoscaling_target" "target" {
  for_each = { for key, value in var.tasks : key => value if lookup(value, "create_service", false) == true }

  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.task[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = each.value.auto_scale_min_capacity
  max_capacity       = each.value.auto_scale_max_capacity
}


