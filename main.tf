provider "aws" {
  region = "ap-northeast-2"
}

locals {
  region = "ap-northeast-2"
}

# S3 bucket for backend
resource "aws_s3_bucket" "tfstate" {
  bucket = "augustkang-tfstate"
  force_destroy = true

  versioning {
    enabled = true # Prevent from deleting tfstate file
  }
}

# DynamoDB for terraform state lock
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "terraform-lock"
  hash_key     = "LockID"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }
}

module "vpc" {
  source          = "./vpc"
  project_name    = "august"
  cidr            = "10.0.0.0/16"
  azs             = ["${local.region}a", "${local.region}c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
}
