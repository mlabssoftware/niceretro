variable "application_name" {}
variable "environment" {}

variable "secret_name" {
  default = null
}

variable "ecr_repository_url" {
  default = null
}

variable "region" {}
variable "vpc_id" {}
variable "public_subnet_ids" {}
variable "private_subnet_ids" {}

variable "vpc_cidr" {}

variable "tasks" {
  description = "Configuração das tasks do ECS. Podem ser configuradas N tasks ao mesmo tempo."
}

variable "execution_role_aditional_permissions" {
  default = []
}

locals {
  tags = {
    Environment = var.environment
    Name        = var.application_name
  }
}
