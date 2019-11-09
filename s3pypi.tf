variable "region" {
  default = "us-east-1"
}
variable "name_prefix" {}
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "gen_index_version" {
  default = "0.1.6"
}
variable "gen_proj_index_version" {
  default = "0.2.1"
}

provider "aws" {
  region = var.region
  version = "~> 2.35"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "${var.name_prefix}-artifacts"
  acl = "public-read"
  policy = <<POLICY
{ "Version" : "2012-10-17",
  "Statement" : [
    { "Sid" : "",
      "Effect" : "Allow",
      "Principal" : "*",
      "Action" : ["s3:GetObject"],
      "Resource" : "arn:aws:s3:::${var.name_prefix}-artifacts/*"
    }
  ]
}
POLICY
}

resource "aws_s3_bucket" "index_bucket" {
  bucket = "${var.name_prefix}-index"
  acl = "public-read"
  policy = <<POLICY
{ "Version" : "2012-10-17",
  "Statement" : [
    { "Sid" : "",
      "Effect" : "Allow",
      "Principal" : "*",
      "Action" : ["s3:GetObject"],
      "Resource" : "arn:aws:s3:::${var.name_prefix}-index/*"
    }
  ]
}
POLICY
  website {
    index_document = "index.html"
  }
}

resource "aws_sns_topic" "update_topic" {
  name = "${var.name_prefix}-updates"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS":"*"},
    "Action": "SNS:Publish",
    "Resource": "arn:aws:sns:*:*:${var.name_prefix}-updates",
    "Condition": {
      "ArnLike" : { "aws:SourceArn": "${aws_s3_bucket.artifact_bucket.arn}" }
    } 
   }]
}
POLICY
}


resource "aws_s3_bucket_notification" "artifact_notification" {
  bucket = "${aws_s3_bucket.artifact_bucket.id}"
  topic {
    topic_arn = "${aws_sns_topic.update_topic.arn}"
    events = ["s3:ObjectCreated:*","s3:ObjectRemoved:*"]
  }
}

resource "aws_sns_topic" "rebuild_root_topic" {
  name = "${var.name_prefix}-rebuild-root"
}

resource "aws_iam_role" "gen_index_role" {
  name = "${var.name_prefix}-gen-index"
  assume_role_policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [
    { "Action" : "sts:AssumeRole",
      "Principal" : {
        "Service" : "lambda.amazonaws.com"
      },
      "Effect" : "Allow",
      "Sid" : ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "gen_index_basic_lambda" {
  role = "${aws_iam_role.gen_index_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "generate_base_index" {
  name = "${var.name_prefix}-generate-base-index"
  policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [
    { "Sid" : "",
      "Effect" : "Allow",
      "Action" : [
        "s3:HeadBucket",
        "s3:ListObjects"
      ],
      "Resource" : [
        "arn:aws:s3:::${aws_s3_bucket.index_bucket.bucket}"
      ]
    },
    {
      "Sid" : "",
      "Effect" : "Allow",
      "Action" : "s3:*",
      "Resource" : [
        "arn:aws:s3:::${aws_s3_bucket.index_bucket.bucket}/index.html"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "gen_index_s3_access" {
  role = "${aws_iam_role.gen_index_role.name}"
  policy_arn = "${aws_iam_policy.generate_base_index.arn}"
}

resource "aws_iam_role" "gen_proj_index_role" {
  name = "${var.name_prefix}-gen-proj-index"
  assume_role_policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [
    { "Action" : "sts:AssumeRole",
      "Principal" : {
        "Service" : "lambda.amazonaws.com"
      },
      "Effect" : "Allow",
      "Sid" : ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "gen_proj_index_basic_lambda" {
  role = "${aws_iam_role.gen_proj_index_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "generate_proj_index" {
  name = "${var.name_prefix}-generate-proj-index"
  policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [
    { "Sid" : "",
      "Effect" : "Allow",
      "Action" : [
        "s3:HeadBucket",
        "s3:ListObjects"
      ],
      "Resource" : [
        "arn:aws:s3:::${aws_s3_bucket.artifact_bucket.bucket}"
      ]
    },
    {
      "Sid" : "",
      "Effect" : "Allow",
      "Action" : "s3:*",
      "Resource" : [
        "arn:aws:s3:::${aws_s3_bucket.index_bucket.bucket}/*/index.html",
        "arn:aws:s3:::${aws_s3_bucket.index_bucket.bucket}/*/"
      ]
    },
    {
      "Sid" : "",
      "Effect" : "Allow",
      "Action" : "SNS:Publish",
      "Resource": "${aws_sns_topic.rebuild_root_topic.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "gen_proj_index_s3_access" {
  role = "${aws_iam_role.gen_proj_index_role.name}"
  policy_arn = "${aws_iam_policy.generate_proj_index.arn}"
}

resource "aws_lambda_function" "gen_index_lambda" {
  s3_bucket = "${var.name_prefix}-lambdas"
  s3_key = "${var.name_prefix}-gen-index/${var.name_prefix}-gen-index-${var.gen_index_version}.zip"
  function_name = "${var.name_prefix}-gen-index"
  role = "${aws_iam_role.gen_index_role.arn}"
  handler = "handler.handle"
  runtime = "python3.7"
  environment {
    variables = {
      INDEX_BUCKET = "${aws_s3_bucket.index_bucket.bucket}"
    }
  }
}

resource "aws_lambda_permission" "gen_index_from_sns" {
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.gen_index_lambda.function_name}"
  principal = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.rebuild_root_topic.arn}"
}

resource "aws_sns_topic_subscription" "gen_index_sub" {
  topic_arn = "${aws_sns_topic.rebuild_root_topic.arn}"
  protocol = "lambda"
  endpoint = "${aws_lambda_function.gen_index_lambda.arn}"
}

resource "aws_lambda_function" "gen_proj_index_lambda" {
  s3_bucket = "${var.name_prefix}-lambdas"
  s3_key = "${var.name_prefix}-gen-proj-index/${var.name_prefix}-gen-proj-index-${var.gen_proj_index_version}.zip"
  function_name = "${var.name_prefix}-gen-proj-index"
  role = "${aws_iam_role.gen_proj_index_role.arn}"
  handler = "handler.handle"
  runtime = "python3.7"
  environment {
    variables = {
      INDEX_BUCKET = "${aws_s3_bucket.index_bucket.bucket}"
      ARTIFACT_BUCKET = "${aws_s3_bucket.artifact_bucket.bucket}"
      REBUILD_ROOT_TOPIC = "${aws_sns_topic.rebuild_root_topic.arn}"
    }
  }
}

resource "aws_lambda_permission" "gen_proj_index_from_sns" {
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.gen_proj_index_lambda.function_name}"
  principal = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.update_topic.arn}"
}

resource "aws_sns_topic_subscription" "gen_proj_index_sub" {
  topic_arn = "${aws_sns_topic.update_topic.arn}"
  protocol = "lambda"
  endpoint = "${aws_lambda_function.gen_proj_index_lambda.arn}"
}

resource "aws_cloudfront_distribution" "index_distrib" {
  enabled = true
  is_ipv6_enabled = true
  origin {
    origin_id = "${var.name_prefix}-origin"
    domain_name = "${aws_s3_bucket.index_bucket.bucket}.${aws_s3_bucket.index_bucket.website_domain}"
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }
  default_root_object = "index.html"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  default_cache_behavior {
    allowed_methods = ["GET","HEAD","OPTIONS"]
    cached_methods = ["GET","HEAD"]
    compress = true
    default_ttl = 0
    target_origin_id = "${var.name_prefix}-origin"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies {
	forward = "none"
      }
    }
  }
}
