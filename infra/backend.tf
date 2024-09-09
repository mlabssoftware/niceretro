terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.66.0"
    }
  }
/*
  backend "s3" {
    bucket         = "mlabs-test-tfstate"
    key            = "deployment-terraform-test/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "mlabs-test-locks"
  }
  */
}

provider "aws" {
  region = var.aws_region
}
