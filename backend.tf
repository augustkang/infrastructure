terraform {
    backend "s3" {
      bucket         = "augustkang-tfstate"
      key            = "terraform.tfstate"
      region         = "ap-northeast-2"
      encrypt        = true
      dynamodb_table = "terraform-lock"
    }
}
