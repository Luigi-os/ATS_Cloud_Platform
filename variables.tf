# Declaration of all the variables used in the project.

# --------------------------- Input Variables --------------------------- #

variable "project-name" {
    description = "Nome del progetto."
    type        = string
    default     = "gg-cv-archive-project"
}

variable "environment" {
    description = "Ambiente di deployment."
    type        = string
    default     = "dev"
}

variable "region" {
    description = "Regione AWS in cui creare le risorse."
    type        = string
    default     = "eu-north-1"
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