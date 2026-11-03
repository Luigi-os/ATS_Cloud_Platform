# Define the Lambda function

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
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Definition of the Lambda function that processes incoming CVs and stores candidate information in DynamoDB and archives the CVs in S3.
resource "aws_lambda_function" "cv_llm_parser" {
  function_name    = "${var.project-name}-cv-llm-parser"
  role             = aws_iam_role.lambda_role.arn # The IAM role with its associated Access Policy. (iam.tf)
  handler          = "main.lambda_handler"        # The entry point for the Lambda function.
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 180 # Left the timeout to 180 seconds for testing if the Lambda function can process the CVs in time. 
  memory_size = 256

  layers = [
    aws_lambda_layer_version.python_dependencies.arn
  ]
  # Define environment variables for the Lambda function to access the DynamoDB table and S3 bucket.
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.candidates_table.name
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

  enabled = true
}
