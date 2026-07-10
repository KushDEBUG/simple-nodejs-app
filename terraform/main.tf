terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- KMS key for bucket encryption ---
resource "aws_kms_key" "demo_key" {
  description         = "KMS key for devsecops demo bucket encryption"
  enable_key_rotation = true
}

# --- Logging target bucket (separate, cannot log to itself) ---
resource "aws_s3_bucket" "log_bucket" {
  #checkov:skip=CKV_AWS_18:Log bucket does not need its own access logging
  bucket = "devsecops-demo-log-bucket"
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket                  = aws_s3_bucket.log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- Main demo bucket ---
resource "aws_s3_bucket" "demo_bucket" {
  #checkov:skip=CKV2_AWS_62:Not needed for demo project, no downstream event processing
  #checkov:skip=CKV_AWS_144:Cross-region replication not needed for demo project
  bucket = "devsecops-demo-artifacts-bucket"

  tags = {
    Project = "simple-nodejs-app"
  }
}

resource "aws_s3_bucket_public_access_block" "demo_bucket" {
  bucket                  = aws_s3_bucket.demo_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.demo_key.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "demo_bucket" {
  bucket        = aws_s3_bucket.demo_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
