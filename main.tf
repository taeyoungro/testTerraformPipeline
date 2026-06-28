terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}


# ==========================================
# 2. 테스트용 AWS VPC 리소스
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.10.10.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "my-tf-vpc"
    ManagedBy   = "Terraform"
  }
}

