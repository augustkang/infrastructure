provider "aws" {
  region = "ap-northeast-2"
}

locals {
  region = "ap-northeast-2"
}

module "vpc" {
  source          = "./vpc"
  project_name    = "august"
  cidr            = "10.0.0.0/16"
  azs             = ["${local.region}a", "${local.region}c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
}
