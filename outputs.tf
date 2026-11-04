# Esportazione dei valori chiave (es. ARN delle risorse o URL dei bucket) per verificare il completamento del deployment.

output "incoming_bucket_name" {
  description = "Nome del bucket S3 per i file in ingresso."
  value       = aws_s3_bucket.cv_incoming_bucket.bucket
}

output "incoming_bucket_arn" {
  description = "ARN del bucket S3 per i file in ingresso."
  value       = aws_s3_bucket.cv_incoming_bucket.arn
}

output "archive_bucket_name" {
  description = "Nome del bucket S3 di archivio."
  value       = aws_s3_bucket.cv_archive_bucket.bucket
}

output "processing_queue_url" {
  description = "URL della coda SQS di elaborazione."
  value       = aws_sqs_queue.processing_queue.url
}

output "processing_queue_arn" {
  description = "ARN della coda SQS di elaborazione."
  value       = aws_sqs_queue.processing_queue.arn
}

output "dlq_queue_url" {
  description = "URL della Dead Letter Queue."
  value       = aws_sqs_queue.dlq.url
}

output "dynamodb_table_name" {
  description = "Nome della tabella DynamoDB dei candidati."
  value       = aws_dynamodb_table.candidates_table.name
}

output "dynamodb_table_arn" {
  description = "ARN della tabella DynamoDB dei candidati."
  value       = aws_dynamodb_table.candidates_table.arn
}

output "lambda_function_name" {
  description = "Nome della funzione Lambda."
  value       = aws_lambda_function.cv_llm_parser.function_name
}

output "lambda_function_arn" {
  description = "ARN della funzione Lambda."
  value       = aws_lambda_function.cv_llm_parser.arn
}

output "api_endpoint" {
  value       = aws_apigatewayv2_api.http_api.api_endpoint
  description = "URL base dell'API Gateway da inserire nel frontend"
}