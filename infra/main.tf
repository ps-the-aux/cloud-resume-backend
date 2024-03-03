resource "aws_s3_bucket" "website" {
  bucket = "cloud-resume-challenge19"

}

resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = aws_s3_bucket.website.id
  policy = <<EOF
   {
        "Version": "2008-10-17",
        "Id": "PolicyForCloudFrontPrivateContent",
        "Statement": [
            {
                "Sid": "AllowCloudFrontServicePrincipal",
                "Effect": "Allow",
                "Principal": {
                    "Service": "cloudfront.amazonaws.com"
                },
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::cloud-resume-challenge19/*",
                "Condition": {
                    "StringEquals": {
                      "AWS:SourceArn": "arn:aws:cloudfront::905418409332:distribution/E2R8WPASJY5TY"
                    }
                }
            }
        ]
      }
EOF
}

locals {
  s3_origin_id = "S3-${aws_s3_bucket.website.id}"
}

resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "s3-access-control"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  aliases = ["resume.faisalorainan.cloud"]

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"


  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:905418409332:certificate/3f815f56-983d-4018-bcfa-eee685c06306"
    ssl_support_method  = "sni-only"
  }
}

resource "aws_route53domains_registered_domain" "domain" {
  domain_name = "faisalorainan.cloud"

}

resource "aws_route53_zone" "primary" {
  name = "faisalorainan.cloud"
}

import {
  to = aws_route53_zone.primary
  id = "Z06201262FS02S8TESN6O"

}

resource "aws_route53_record" "ns" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "faisalorainan.cloud"
  type    = "NS"
  ttl     = "172800"
  records = ["ns-1450.awsdns-53.org", "ns-971.awsdns-57.net", "ns-508.awsdns-63.com", "ns-1868.awsdns-41.co.uk"]
}

import {
  to = aws_route53_record.ns
  id = "Z06201262FS02S8TESN6O_faisalorainan.cloud_NS"
}

resource "aws_route53_record" "soa" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "faisalorainan.cloud"
  type    = "SOA"
  ttl     = "900"
  records = ["ns-1450.awsdns-53.org. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"]

}

import {
  to = aws_route53_record.soa
  id = "Z06201262FS02S8TESN6O_faisalorainan.cloud_SOA"
}

resource "aws_route53_record" "a" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "resume.faisalorainan.cloud"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }

}

import {
  to = aws_route53_record.a
  id = "Z06201262FS02S8TESN6O_resume.faisalorainan.cloud_A"
}

resource "aws_dynamodb_table" "cloud-resume-datastore" {
  name           = "cloud-resume-datastore"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "Id"

  attribute {
    name = "Id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "id" {
  table_name = aws_dynamodb_table.cloud-resume-datastore.name
  hash_key   = aws_dynamodb_table.cloud-resume-datastore.hash_key

  item = <<ITEM
    {
        "Id": {"S": "1"},
        "Views": {"N": "1"}
    }
ITEM
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "policy" {
    statement {
        sid       = "AllowDynamoDB"
        effect    = "Allow"
        actions   = [
            "dynamodb:*"]
        resources = ["arn:aws:dynamodb:us-east-1:905418409332:table/cloud-resume-datastore"]
    }
}

resource "aws_iam_policy" "policy" {
    name   = "iam_for_lambda_policy"
    policy = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
    role       = aws_iam_role.iam_for_lambda.name
    policy_arn = aws_iam_policy.policy.arn
}

data "archive_file" "lambda_put_zip" {
  type        = "zip"
  source_file  = "${path.module}/lambda_functions/db_put.py"
  output_path = "${path.module}/lambda_functions/db_put.zip"

}

resource "aws_lambda_function" "lambda_put" {
  filename         = data.archive_file.lambda_put_zip.output_path
  function_name    = "lambda_db_put_function"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "db_put.lambda_handler"
  source_code_hash = data.archive_file.lambda_put_zip.output_base64sha256
  runtime          = "python3.12"
}

resource "aws_lambda_function_url" "put_url" {
    function_name = aws_lambda_function.lambda_put.function_name
    authorization_type = "NONE"
    cors {
        allow_origins = ["*"]
    }
}

resource "aws_lambda_function_url" "get_url" {
  function_name = aws_lambda_function.lambda_get.function_name
  authorization_type = "NONE"
  cors {
      allow_origins = ["*"]
  }
}

data "archive_file" "lambda_get_zip" {
  type        = "zip"
  source_file  = "${path.module}/lambda_functions/db_get.py"
  output_path = "${path.module}/lambda_functions/db_get.zip"
  
}

resource "aws_lambda_function" "lambda_get" {
  filename         = data.archive_file.lambda_get_zip.output_path
  function_name    = "lambda_db_get_function"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "db_get.lambda_handler"
  source_code_hash = data.archive_file.lambda_get_zip.output_base64sha256
  runtime          = "python3.12"
}

resource "aws_apigatewayv2_api" "resume_api" {
    name          = "resume_api"
    protocol_type = "HTTP"
    cors_configuration {
        allow_origins = ["*"]
    }
}

resource "aws_apigatewayv2_route" "post" {
    api_id    = aws_apigatewayv2_api.resume_api.id
    route_key = "ANY /"
    target    = "integrations/${aws_apigatewayv2_integration.put.id}"
}

resource "aws_apigatewayv2_integration" "put" {
    api_id            = aws_apigatewayv2_api.resume_api.id
    integration_type  = "AWS_PROXY"
    integration_method = "POST"
    integration_uri   = aws_lambda_function.lambda_put.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_stage" "default" {
    api_id      = aws_apigatewayv2_api.resume_api.id
    name        = "$default"
    auto_deploy = true
  
}

resource "aws_lambda_permission" "allow-api-gateway-to-invoke-lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_put.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.resume_api.execution_arn}/*"
}

resource "aws_apigatewayv2_deployment" "resume_api" {
    api_id      = aws_apigatewayv2_api.resume_api.id
    description = "Deployment for the resume api"
    
    lifecycle {
        create_before_destroy = true
    }
}
