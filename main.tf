terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # [주의] 최초 실행 시에는 아래 backend 블록을 주석 처리하고 실행(local state)한 뒤, 
  # S3와 DynamoDB가 생성되면 주석을 해제하고 다시 `terraform init`을 해야 합니다.
  backend "s3" {
    bucket         = "my-terraform-state-bucket-unique" # 본인의 S3 버킷 이름으로 변경
    key            = "github-actions/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# ==========================================
# 1. Terraform Backend (State & Lock)
# ==========================================

# State를 저장할 S3 버킷
resource "aws_s3_bucket" "state" {
  bucket        = "my-terraform-state-bucket-unique" # 전 세계 유일한 이름 필요
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 동시 실행 제어(Lock)를 위한 DynamoDB 테이블
resource "aws_dynamodb_table" "lock" {
  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ==========================================
# 2. GitHub Actions OIDC 및 IAM Role 설정
# ==========================================

# GitHub OIDC Identity Provider 등록
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1c5876d765b004291823297a5344445854b791fc"] # GitHub OIDC 지문
}

# GitHub Actions가 Assume 할 IAM Role
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsWorkflowRole"

  # 특정 GitHub 레포지토리의 워크플로우만 이 Role을 가질 수 있도록 신뢰 관계(Trust Relationship) 정의
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # 본인의 GitHub 계정명(또는 Org명)과 레포지토리 이름으로 변경해야 합니다.
            # 예: "repo:my-github-id/my-repo-name:*"
            "token.actions.githubusercontent.com:sub" = "repo:<YOUR_GITHUB_ID>/<YOUR_REPO_NAME>:*"
          }
        }
      }
    ]
  })
}

# 파이프라인이 리소스를 생성할 수 있도록 AdministratorAccess 권한 부여 (필요에 따라 최소 권한으로 조정 가능)
resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ==========================================
# 3. 요청하신 AWS 리소스 (VPC)
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.10.10.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "my-tf-vpc"
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}

# ==========================================
# Outputs (생성된 IAM Role ARN 확인용)
# ==========================================

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "GitHub Actions 워크플로우 YAML의 role-to-assume 에 넣을 ARN입니다."
}