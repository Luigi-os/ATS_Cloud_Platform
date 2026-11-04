# Configuration for the DynamoDB table used to store candidate information.
resource "aws_dynamodb_table" "candidates_table" {
    name = local.dynamodb_table_name # Unique identifier for the DynamoDB table.
    billing_mode = "PAY_PER_REQUEST" # On-demand billing mode for the table.
    hash_key = "CandidateID" # Primary key for the table.

    attribute {
        name = "CandidateID" # Name of the primary key attribute.
        type = "S" # Type of the primary key attribute (String).
    }

    attribute {
        name = "job_id"
        type = "S"
    }

    attribute {
        name = "score"
        type = "N"
    }
    # Define a global secondary index (GSI) for querying candidates by job role and score.
    global_secondary_index {
        name = "JobIdScoreIndex" 
        key_schema {
            attribute_name = "job_id"
            key_type       = "HASH" # Hash key for the GSI.
        }
        key_schema {
            attribute_name = "score"
            key_type       = "RANGE" # Range key for the GSI.
        }
        projection_type = "ALL" # Copies all attributes from the table into the index.
    }
}

# Configuration for the DynamoDB table used to store job information.
# Description and JobSkills don't need to be defined as attributes in the table since they are not used for querying. They will be stored as part of the item data.
resource "aws_dynamodb_table" "jobs_table" {
  name         = "${var.project-name}-jobs-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_id"

  attribute {
    name = "job_id"
    type = "S"
  }
}
