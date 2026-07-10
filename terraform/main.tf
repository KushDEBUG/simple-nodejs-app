resource "aws_s3_bucket" "demo_bucket" {
  bucket = "devsecops-demo-artifacts-bucket"

  tags = {
    Project = "simple-nodejs-app"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm      = "aws:kms"
      kms_master_key_id  = aws_kms_key.s3_key.arn
    }
    bucket_key_enabled = true
  }
}

# Enable access logging
resource "aws_s3_bucket_logging" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "access-logs/"
}

# Enable lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id

  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable event notifications
resource "aws_s3_bucket_notification" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id

  topic {
    topic_arn = aws_sns_topic.s3_events.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

# Create KMS key for encryption
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "s3_key" {
  name          = "alias/s3-bucket-key"
  target_key_id = aws_kms_key.s3_key.key_id
}

# Create logging bucket
resource "aws_s3_bucket" "log_bucket" {
  bucket = "devsecops-demo-logs-bucket"

  tags = {
    Project = "simple-nodejs-app"
  }
}

# Create SNS topic for event notifications
resource "aws_sns_topic" "s3_events" {
  name = "s3-events-topic"
}
