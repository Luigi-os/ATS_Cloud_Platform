# Define the IAM role for the parser Lambda function to assume when it is invoked. This role allows the Lambda function to access AWS services and resources.
resource "aws_iam_role" "lambda_role" {
    name = "${local.name_prefix}-lambda-role"
    # Define the Trust Policy that allows the Lambda service to assume this role.
    assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
        {
            "Action" = "sts:AssumeRole"
            "Effect" = "Allow"
            "Principal" = {
                "Service" = "lambda.amazonaws.com"
            },
        }
        ]
    })
}

# Define the IAM policy for the Lambda function to grant it the necessary permissions to access S3, SQS, DynamoDB, and CloudWatch Logs.
resource "aws_iam_role_policy" "lambda_policy" {
    name = "${local.name_prefix}-lambda-policy"
    role = aws_iam_role.lambda_role.id
    
    policy = jsonencode({
        "Version" = "2012-10-17"
        "Statement" = [
        {
        "Effect" = "Allow"
        "Action" = [
            "s3:GetObject",
            "s3:DeleteObject"
        ]
        "Resource" = "${aws_s3_bucket.cv_incoming_bucket.arn}/*" # The Lambda function needs to read and delete objects from the incoming S3 bucket.
        },
        {
        "Sid" = "S3ArchiveBucketAccess"
        "Effect" = "Allow"
        "Action" = [
            "s3:PutObject"
        ]
        "Resource" = "${aws_s3_bucket.cv_archive_bucket.arn}/*" # The Lambda function needs to write objects to the archive S3 bucket.
        },
        {
        "Sid" = "SQSServiceAccess"
        "Effect" = "Allow"
        "Action" = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes" 
        ]
        "Resource" = "${aws_sqs_queue.processing_queue.arn}" # The Lambda function needs to receive and delete messages from the processing SQS queue.
        },
        {
        "Sid" = "DynamoDBTableAccess"
        "Effect" = "Allow"
        "Action" = [
            "dynamodb:PutItem"
        ]
        "Resource" = "${aws_dynamodb_table.candidates_table.arn}" # The Lambda function needs to put items into the Candidates DynamoDB table.
        },
        {
        "Sid" = "DynamoDBJobsReadAccess"
        "Effect" = "Allow"
        "Action" = [
            "dynamodb:GetItem"
        ]
        "Resource" = "${aws_dynamodb_table.jobs_table.arn}"
        }
        ]
    })
}

# Define the IAM role for the API Lambda function to assume when it is invoked. This role allows the API Lambda function to access AWS services and resources.
# Ruolo di esecuzione per la Lambda API
resource "aws_iam_role" "api_lambda_role" {
  name = "${var.project-name}-api-lambda-role"
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [{
      "Action" = "sts:AssumeRole"
      "Effect" = "Allow"
      "Principal" = { "Service" = "lambda.amazonaws.com" }
    }]
  })
}

# The policy that we need is 
resource "aws_iam_role_policy" "api_lambda_policy" {
    name = "${var.project-name}-api-lambda-policy"
    role = aws_iam_role.api_lambda_role.id
    
    policy = jsonencode({
        "Version" = "2012-10-17"
        "Statement" = [
        {
            "Effect" = "Allow"
            "Action" = [
            "dynamodb:Scan",
            "dynamodb:PutItem",
            "dynamodb:DeleteItem"
            ]
            "Resource" = aws_dynamodb_table.jobs_table.arn
        },
        {
            "Effect" = "Allow"
            "Action" = [
            "dynamodb:Query",
            "dynamodb:Scan"
            ]
            "Resource" = [
            aws_dynamodb_table.candidates_table.arn,
            "${aws_dynamodb_table.candidates_table.arn}/index/*"
            ]
        },
        {
            "Effect" = "Allow"
            "Action" = [
            "s3:PutObject"
            ]
            "Resource" = "${aws_s3_bucket.cv_incoming_bucket.arn}/*"
        },
        {
            "Effect" = "Allow"
            "Action" = [
            "s3:GetObject"
            ]
            "Resource" = "${aws_s3_bucket.cv_archive_bucket.arn}/*"
        }
        ]
    })
}
