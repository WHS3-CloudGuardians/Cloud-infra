resource "aws_s3_bucket" "vuln_config_logs" {
  bucket = "vuln-config-logs"
}

resource "aws_s3_bucket_public_access_block" "disable_block_public_policy" {
  bucket = aws_s3_bucket.vuln_config_logs.id

  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "vuln_config_policy" {
  bucket = aws_s3_bucket.vuln_config_logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSConfigBucketPermissionsCheck",
        Effect    = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        },
        Action    = ["s3:GetBucketAcl"],
        Resource  = aws_s3_bucket.vuln_config_logs.arn
      },
      {
        Sid       = "AWSConfigBucketDelivery",
        Effect    = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        },
        Action    = ["s3:PutObject"],
        Resource  = "${aws_s3_bucket.vuln_config_logs.arn}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "config_role" {
  name = "vuln-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_config_configuration_recorder" "vuln_recorder" {
  name     = "config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "vuln_delivery" {
  name           = "vuln-delivery"
  s3_bucket_name = aws_s3_bucket.vuln_config_logs.bucket

  depends_on = [aws_config_configuration_recorder.vuln_recorder]
}

resource "aws_config_configuration_recorder_status" "vuln_status" {
  name       = aws_config_configuration_recorder.vuln_recorder.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.vuln_delivery]
}

