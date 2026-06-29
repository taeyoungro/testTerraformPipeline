terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 변수(var.)를 제거하고 리전을 직접 지정하여 독립성을 확보합니다.
provider "aws" {
  region = "ap-northeast-2" 
}

# AWS VPC 리소스 단일 생성
resource "aws_vpc" "main" {
  cidr_block           = "10.10.10.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "my-tf-vpc"
    ManagedBy = "Terraform"
  }
}
