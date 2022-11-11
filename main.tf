provider "aws" {
  region = "ap-northeast-2"
}

locals {
  region = "ap-northeast-2"
}

module "vpc" {
  source          = "./modules/vpc"
  project_name    = "august"
  cidr            = "10.0.0.0/16"
  azs             = ["${local.region}a", "${local.region}c"]
  public_subnets  = ["10.0.0.0/18", "10.0.64.0/18"]
  private_subnets = ["10.0.128.0/18", "10.0.192.0/18"]
}
