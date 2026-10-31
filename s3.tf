# Declaration of the S3 buckets used in the project.

# S3 bucket for incoming files (cv-incoming-bucket) configuration.
resource "aws_s3_bucket" "cv_incoming_bucket" {
    
    bucket = local.bucket_incoming_name # Identificativo univoco del bucket S3. (definito in variables.tf)
    force_destroy = true # Abilita la rimozione del bucket anche se contiene oggetti. (Per il testing)
    tags = {
        Name        = "CV Incoming Bucket"
        Environment = var.environment
    }
}

# Configuration of the server-side encryption for the ingestion bucket.
# From January 5, 2023, AWS automatically applies the default server-side encryption SSE-S3 (AES-256) to every new object uploaded to Amazon S3.
# We decide to explicitly specify it for compliance.
resource "aws_s3_bucket_server_side_encryption_configuration" "cv_incoming_encryption" {
    bucket = aws_s3_bucket.cv_incoming_bucket.id 

    rule {
        apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
        }
    }
}

# Configuration of the S3 bucket notification to trigger the SQS queue when a new object is created in the incoming bucket.
resource "aws_s3_bucket_notification" "incoming_bucket_notification" {
    bucket = aws_s3_bucket.incoming_bucket.id

    queue {
        queue_arn     = aws_sqs_queue.cv_processing_queue.arn
        events        = ["s3:ObjectCreated:*"]
    }

    # With depends_on attribute this resource will be created after the SQS queue policy is created.
    depends_on = [
        aws_sqs_queue_policy.cv_processing_queue_policy
    ]
}

# Configuration of the S3 bucket CORS (Cross-Origin Resource Sharing) to allow cross-origin requests from any origin.
resource "aws_s3_bucket_cors_configuration" "incoming_bucket_cors" {
  bucket = aws_s3_bucket.incoming_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Because the incoming bucket is public, we need to block public access to it. This is made because the project is private.
resource "aws_s3_bucket_public_access_block" "cv_incoming_public_access_block" {
    bucket = aws_s3_bucket.cv_incoming_bucket.id 

    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

# S3 bucket for archive files (cv-archive-bucket) configuration. (DESTINATION BUCKET)
resource "aws_s3_bucket" "cv_archive_bucket" {
    bucket = local.bucket_archive_name 
    force_destroy = true 
    tags = {
        Name        = "CV Archive Bucket"
        Environment = var.environment 
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cv_archive_encryption" {
    bucket = aws_s3_bucket.cv_archive_bucket.id 

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}

resource "aws_s3_bucket_public_access_block" "cv_archive_public_access_block" {
    bucket = aws_s3_bucket.cv_archive_bucket.id 
        
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}
