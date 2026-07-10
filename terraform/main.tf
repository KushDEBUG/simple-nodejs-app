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

data "aws_caller_identity" "current" {}

# --- KMS key for bucket encryption, with an explicit key policy ---
resource "aws_kms_key" "demo_key" {
  description             = "KMS key for devsecops demo bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow S3 to use the key",
      "Effect": "Allow",
      "Principal": { "Service": "s3.amazonaws.com" },
      "Action": [
        "kms:GenerateDataKey",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

# --- Logging target bucket ---
resource "aws_s3_bucket" "log_bucket" {
  #checkov:skip=CKV_AWS_18:Log bucket does not need its own access logging
  #checkov:skip=CKV2_AWS_62:No downstream event processing needed for demo project
  #checkov:skip=CKV_AWS_144:Cross-region replication not needed for demo project
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
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.demo_key.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    id     = "log-retention"
    status = "Enabled"
    expiration {
      days = 365
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- Main demo bucket ---
resource "aws_s3_bucket" "demo_bucket" {
  #checkov:skip=CKV2_AWS_62:No downstream event processing needed for demo project
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
    bucket_key_enabled = true
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
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
