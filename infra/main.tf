data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "subnet" {
  for_each = toset(data.aws_subnets.subnets.ids)
  id       = each.value
}

resource "aws_secretsmanager_secret" "secrets" {
  name = "niceretro-${var.environment}"
}

module "rds" {
  source = "./modules/rds"

  name = "niceretro"
  environment = var.environment

  entries = {
    "v16": {
      rds_vpc           = data.aws_vpc.default.id
      rds_cidr          = data.aws_vpc.default.cidr_block
      rds_subnets       = data.aws_subnets.subnets.ids
      additional_cidr   = []
      access_sg_ids     = []
      sg_ids            = []

      postgresql_db_version = "16.4"
      postgresql_db_family = "postgres16"
      postgresql_db_major = "16"
      postgresql_db_instance_type = "db.t4g.micro"
      postgresql_db_size = "10"
      postgresql_db_user = "root"
      postgresql_db_password = "password"
      postgresql_snapshot = ""
      postgresql_public = true

      parameters = [
        {
          apply_method = "immediate"
          name         = "rds.force_ssl"
          value        = "0"
        }
      ]

    }
  }
}

resource "aws_ecr_repository" "repository" {
  name         = "niceretro"
  force_delete = true
}

module "ecs" {
  source = "./modules/ecs"

  depends_on = [aws_secretsmanager_secret.secrets]

  region = var.aws_region

  application_name = "niceretro"
  environment = var.environment

  vpc_id = data.aws_vpc.default.id
  private_subnet_ids = []
  public_subnet_ids = data.aws_subnets.subnets.ids
  vpc_cidr = data.aws_vpc.default.cidr_block

  ecr_repository_url = aws_ecr_repository.repository.repository_url

  secret_name = aws_secretsmanager_secret.secrets.name
  tasks = {
    "db-setup": {
      task_cpu                = 256
      task_memory             = 512
      entrypoint = ["bash", "-c", "bundle exec rake db:create && bundle exec rake db:migrate && bundle exec rake db:seed"]
      log_retention_days      = 7      
    }
    "web": {
      task_cpu                = 256
      task_memory             = 512
      entrypoint              = ["bundle", "exec", "rails", "s", "-p", "80", "-b", "0.0.0.0"]
      auto_scale_max_capacity = 0
      auto_scale_min_capacity = 0
      assign_public_ip        = true
      log_retention_days      = 7
      create_service          = true
    }
  }
}

resource "null_resource" "db_setup_task_run" {
  depends_on = [
    module.rds,
    module.ecs
  ]

  provisioner "local-exec" {
    command = <<EOF
    aws ecs run-task \
      --cluster ${module.ecs.cluster_name} \
      --task-definition niceretro-db-setup \
      --count 1 --launch-type FARGATE \
      --network-configuration '{
          "awsvpcConfiguration": {
          "assignPublicIp":"ENABLED",
          "securityGroups": ["${module.ecs.security_group_id}"],
          "subnets": ["${data.aws_subnets.subnets.ids[0]}"]
        }
      }'
EOF
  }
}
