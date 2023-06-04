terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.1.0"
    }
  }
  backend "s3" {
    key     = "global/s3/terraform.tfstate"
    encrypt = true
    region  = var.tf_state_region
  }
}

provider "aws" {
  region = var.region
}
