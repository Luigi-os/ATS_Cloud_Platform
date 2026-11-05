# Define the Lambda function for parsing CVs.

# Define a Lambda layer to package Python dependencies for the Lambda function. 
# This layer will be used to include any required Python libraries that are not part of the standard AWS Lambda runtime.
resource "aws_lambda_layer_version" "python_dependencies" {
  filename            = "${path.module}/src/layers/dependencies.zip"
  layer_name          = "${var.project-name}-python-dependencies"
  compatible_runtimes = ["python3.11"]
}

# Source file and destination path for the Lambda function code.
# Terraform will create a zip archive of the Lambda function code located in the "lambda" directory (local) and store it in the root of the module as "lambda.zip". 
# This zip file will be used as the source code for the Lambda function from AWS Lambda service.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/lambda_parser"
  output_path = "${path.module}/src/lambda_parser.zip"
}

# Definition of the Lambda function that processes incoming CVs and stores candidate information in DynamoDB and archives the CVs in S3.
resource "aws_lambda_function" "cv_llm_parser" {
  function_name    = "${var.project-name}-cv-llm-parser"
  role             = aws_iam_role.lambda_role.arn # The IAM role with its associated Access Policy. (iam.tf)
  handler          = "main.lambda_handler" # The entry point for the Lambda function.
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_zip.output_path 
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256 

  timeout     = 120 # Left the timeout to 180 seconds for testing if the Lambda function can process the CVs in time. 
  memory_size = 1024

  layers = [
    aws_lambda_layer_version.python_dependencies.arn
  ]
  # Define environment variables for the Lambda function to access the Candidates table, Jobs table, S3 bucket and the Gemini API key.
  environment {
    variables = {
      CANDIDATES_TABLE = aws_dynamodb_table.candidates_table.name
      JOBS_TABLE     = aws_dynamodb_table.jobs_table.name
      ARCHIVE_BUCKET = aws_s3_bucket.cv_archive_bucket.bucket
      GEMINI_API_KEY = var.gemini_api_key
    }
  }
}

# Define the event source mapping to connect the Lambda function to the SQS queue.
resource "aws_lambda_event_source_mapping" "cv_llm_parser_sqs_mapping" {
  event_source_arn = aws_sqs_queue.processing_queue.arn
  function_name    = aws_lambda_function.cv_llm_parser.arn
  batch_size       = 1

  enabled = true # Enable the event source mapping to allow the Lambda function to be triggered by messages in the SQS queue.
}

# Define the Lambda function for the API backend.

# Define the source file and destination path for the API Lambda function code.
data "archive_file" "api_lambda_zip" {
  type = "zip"
  source_dir  = "${path.module}/src/lambda_api"
  output_path = "${path.module}/src/lambda_api.zip"
}

# Define the Lambda function that serves as the backend for the API Gateway. 
# This function handles HTTP requests and interacts with the Jobs DynamoDB table to retrieve and update job information, and the Incoming S3 bucket for putting CVs.
resource "aws_lambda_function" "api_backend" {
  function_name    = "${var.project-name}-api-backend"
  role             = aws_iam_role.api_lambda_role.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.api_lambda_zip.output_path
  source_code_hash = data.archive_file.api_lambda_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      JOBS_TABLE      = aws_dynamodb_table.jobs_table.name
      CANDIDATES_TABLE = aws_dynamodb_table.candidates_table.name
      INCOMING_BUCKET = aws_s3_bucket.cv_incoming_bucket.bucket
    }
  }
}

# Add permission to the API Lambda function to allow it to be invoked by the API Gateway.
resource "aws_lambda_permission" "api_gw_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}