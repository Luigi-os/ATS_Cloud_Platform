# Define the API Gateway for the HTTP API. This resource creates an API Gateway that will serve as the entry point for HTTP requests to the Lambda function.

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project-name}-http-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
    max_age       = 300
  }
}

# Define the integration between the API Gateway and the Lambda function.
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.api_backend.invoke_arn
}

# Define the routes for the API Gateway:
# 1. GET /jobs: This route retrieves job information from the Jobs DynamoDB table.
resource "aws_apigatewayv2_route" "get_jobs" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /jobs"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 2. POST /jobs: This route allows the creation of new job entries in the Jobs DynamoDB table.
resource "aws_apigatewayv2_route" "post_jobs" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /jobs"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 3. DELETE /jobs/{job_id}: This route allows the deletion of a specific job entry from the Jobs DynamoDB table based on the provided job_id.
resource "aws_apigatewayv2_route" "delete_job" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "DELETE /jobs/{job_id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 4. GET /jobs/{job_id}/candidates: This route retrieves candidate information associated with a specific job from the Candidates DynamoDB table based on the provided job_id.
resource "aws_apigatewayv2_route" "get_job_candidates" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /jobs/{job_id}/candidates"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 5. POST /upload-url: This route generates a pre-signed URL for uploading CVs to the Incoming S3 bucket.
resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# # Set up the default stage for the API Gateway, enabling automatic deployment of changes to the API.
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}
