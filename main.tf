provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "upload_bucket" {
  bucket = var.bucket_name

  tags = {
    Name = "UploaderBucket"
  }
}

resource "aws_s3_bucket_cors_configuration" "upload_cors" {
  bucket = aws_s3_bucket.upload_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}


resource "aws_cognito_user_pool" "user_pool" {
  name = "uploader-user-pool"
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "uploader-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  generate_secret = false

  callback_urls = [
    "http://localhost:3000"
  ]

  logout_urls = [
    "http://localhost:3000"
  ]

  allowed_oauth_flows       = ["implicit"]
  allowed_oauth_scopes      = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers = ["COGNITO"]
}


resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain       = var.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-s3-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.upload_bucket.arn}/*"
      },
      {
        Effect = "Allow",
        Action = ["logs:*"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "generate_presigned_url" {
  filename         = "lambda.zip"
  function_name    = "generate_presigned_url"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "generate_presigned_url.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda.zip")
  timeout          = 10
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "upload-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["OPTIONS", "POST", "GET", "PUT"]
    allow_headers = ["Authorization", "Content-Type", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token", "X-Amz-User-Agent"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.generate_presigned_url.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /generate-presigned-url"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_presigned_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
