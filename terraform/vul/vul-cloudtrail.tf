data "aws_s3_bucket" "vuln_bucket" {
  bucket = "vul-s3-monitor"
}

resource "aws_s3_bucket_policy" "vuln_policy" {
  bucket = data.aws_s3_bucket.vuln_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck",
        Effect    = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action    = "s3:GetBucketAcl",
        Resource  = "arn:aws:s3:::vul-s3-monitor"
      },
      {
        Sid       = "AWSCloudTrailWrite",
        Effect    = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action    = "s3:PutObject",
        Resource  = "arn:aws:s3:::vul-s3-monitor/AWSLogs/311278774159/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "vuln_trail" {
  name                          = "vuln-trail"
  s3_bucket_name                = data.aws_s3_bucket.vuln_bucket.bucket
  is_multi_region_trail        = false
  enable_log_file_validation   = false
  enable_logging               = true
  include_global_service_events = false
}

~                                             
