terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }

    required_version = ">= 1.3.0"
}

provider "aws" {
    region = "us-east-1"
}

resource "random_id" "bucket_id" {
    byte_length = 4
}

resource "aws_s3_bucket" "frontend_bucket" {
    bucket = "swap-page-frontend-${random_id.bucket_id.hex}"
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket" {
  bucket = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend_bucket_config" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "frontend_policy" {
    bucket = aws_s3_bucket.frontend_bucket.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "PublicReadGetObject"
                Effect = "Allow"
                Principal = "*"
                Action = "s3:GetObject"
                Resource = "${aws_s3_bucket.frontend_bucket.arn}/*"
            }
        ]
    })
}

resource "aws_cloudfront_distribution" "frontend_cdn" {
    origin {
        domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
        origin_id = "S3Origin"
    }

    enabled = true
    default_root_object = "index.html"

    default_cache_behavior {
        allowed_methods = ["GET", "HEAD"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3Origin"
        viewer_protocol_policy = "redirect-to-https"

        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }
}