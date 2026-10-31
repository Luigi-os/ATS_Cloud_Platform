# Declare the queue for buffering (cv-processing-queue) and the Dead Letter Queue (cv-dlq). 

resource "aws_sqs_queue" "processing_queue" {
    name = local.sqs_queue_name
    delay_seconds = 0 # Delay in seconds for the delivery of all messages added to the queue.
    max_message_size = 262144 # Maximum size of a message in bytes (256 KB).
    message_retention_seconds = 86400 # Number of seconds that a message is retained in the queue. (24 hours)
    receive_wait_time_seconds = 10 # Long polling wait time in seconds for the ReceiveMessage action.
    
    # Calculate the visibility timeout based on the expected processing time of the messages. The visibility timeout should be greater than the processing time to avoid message duplication.
    visibility_timeout_seconds = 1080
}

resource "aws_sqs_queue" "dlq" {
    name = local.dlq_queue_name
    message_retention_seconds = 1209600 # The time that a message will be retained in the Dead Letter Queue is more than the retention time of the processing queue (14 days).
}

# Configure the redrive policy for the processing queue to send messages to the Dead Letter Queue after a certain number of failed processing attempts.
resource "aws_sqs_queue_redrive_policy" "processing_queue_redrive_policy" {
    queue_url = aws_sqs_queue.processing_queue.id
    redrive_policy = jsonencode({
        deadLetterTargetArn = aws_sqs_queue.dlq.arn 
        maxReceiveCount     = 5 # Maximum number of times a message can be received before being sent to the Dead Letter Queue.
    })
    
}

# Configure the SQS queue policy to allow the S3 bucket to send messages to the processing queue when new objects are created in the incoming bucket.
resource "aws_sqs_queue_policy" "cv_processing_queue_policy" {
    queue_url = aws_sqs_queue.cv_processing_queue.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Sid       = "AllowS3ToPublishMessages"
            Effect    = "Allow"
            Principal = {
            Service = "s3.amazonaws.com"
            }
            Action   = "sqs:SendMessage"
            Resource = aws_sqs_queue.cv_processing_queue.arn
            # Add a condition to allow only the specific S3 bucket to send messages to the SQS queue.
            Condition = {
                ArnEquals = {
                    "aws:SourceArn" = aws_s3_bucket.incoming_bucket.arn
                }
            }
        }
        ]
    })
}