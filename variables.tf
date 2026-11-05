# Declaration of all the variables used in the project.

# --------------------------- Input Variables --------------------------- #

variable "project-name" {
    description = "Name of the project. This variable is used to create unique names for AWS resources."
    type        = string
    default     = "gg-cv-archive-project"
}

variable "environment" {
    description = "Environment in which the resources will be created."
    type        = string
    default     = "dev"
}

variable "region" {
    description = "Aws region where the resources will be created."
    type        = string
    default     = "eu-north-1"
}

variable "gemini_api_key" {
  description = "API Key to authenticate requests to the Gemini API for CV parsing."
  type        = string
  sensitive   = true 
}

# --------------------------- Local Variables --------------------------- #

# Local variables for resource names.
locals {
    name_prefix = "${var.project-name}-${var.environment}"

    bucket_incoming_name = "${local.name_prefix}-incoming-bucket-${random_id.suffix.hex}"
    bucket_archive_name = "${local.name_prefix}-archive-bucket-${random_id.suffix.hex}"

    lambda_function_name = "${local.name_prefix}-lambda-function-${random_id.suffix.hex}"
    
    sqs_queue_name = "${local.name_prefix}-sqs-queue-${random_id.suffix.hex}"
    dlq_queue_name = "${local.name_prefix}-dlq-queue-${random_id.suffix.hex}"

    dynamodb_table_name = "${local.name_prefix}-candidates-table-${random_id.suffix.hex}"

}