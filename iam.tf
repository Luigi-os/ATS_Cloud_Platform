# Define the IAM role for the Lambda function to assume when it is invoked. This role allows the Lambda function to access AWS services and resources.
resource "aws_iam_role" "lambda_role" {
    name = "${local.name_prefix}-lambda-role"
    # Define the Trust Policy that allows the Lambda service to assume this role.
    assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole"
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com" 
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
    "Version": "2012-10-17",
    "Statement": [
        {
        "Sid": "S3IncomingBucketAccess",
        "Effect": "Allow",
        "Action": [
            "s3:GetObject",
            "s3:DeleteObject"
        ],
        "Resource": "${aws_s3_bucket.cv_incoming_bucket.arn}/*" # The Lambda function needs to read and delete objects from the incoming S3 bucket.
        },
        {
        "Sid": "S3ArchiveBucketAccess",
        "Effect": "Allow",
        "Action": [
            "s3:PutObject"
        ],
        "Resource": "${aws_s3_bucket.cv_archive_bucket.arn}/*" # The Lambda function needs to write objects to the archive S3 bucket.
        },
        {
        "Sid": "SQSServiceAccess",
        "Effect": "Allow",
        "Action": [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes" 
        ],
        "Resource": "${aws_sqs_queue.processing_queue.arn}" # The Lambda function needs to receive and delete messages from the processing SQS queue.
        },
        {
        "Sid": "DynamoDBTableAccess",
        "Effect": "Allow",
        "Action": [
            "dynamodb:PutItem"
        ],
        "Resource": "${aws_dynamodb_table.candidates_table.arn}" # The Lambda function needs to put items into the Candidates DynamoDB table.
        },
        {
        "Sid": "DynamoDBJobsReadAccess",
        "Effect": "Allow",
        "Action": [
            "dynamodb:GetItem"
        ],
        "Resource": "${aws_dynamodb_table.jobs_table.arn}"
        },
        {
        "Sid": "CloudWatchLogging", 
        "Effect": "Allow",
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:${var.region}:*:*" # The Lambda function needs to create log groups, log streams, and put log events in CloudWatch Logs.
        }
        ]
    })
}