output "bucket_name" {
  value = aws_s3_bucket.upload_bucket.bucket
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "cognito_login_url" {
  value = "https://${aws_cognito_user_pool_domain.user_pool_domain.domain}.auth.${var.region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.client.id}&response_type=token&scope=email+openid+profile&redirect_uri=http://localhost:3000"
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.client.id
}

output "user_pool_id" {
  value = aws_cognito_user_pool_client.client.id
  }

output "cognito_domain" {
  description = "The custom domain prefix for Cognito User Pool"
  value       = aws_cognito_user_pool_domain.user_pool_domain.domain
}
