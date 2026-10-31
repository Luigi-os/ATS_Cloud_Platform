# This file contains the configuration for the Terraform providers and backend and random resources that do not directly fall into individual functional modules. 

terraform{
    # Configuration of the S3 backend for Terraform remote state. (Secure)
    backend "s3" {
        bucket = "gg-cv-test-bucket-state-00000" # Unique identifier of the S3 bucket where the Terraform state file will be stored.
        key    = "dev/terraform.tfstate" # Path of the state file within the S3 bucket.
        region = "eu-north-1" # Hardcoded because the S3 resource has already been created previously.
        encrypt = true # Enables encryption of the state file.
        use_lockfile = true # Enables locking of the state file.
    }
    # Configuration of the providers required by Terraform.
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 6.0" # Minimum version of the AWS provider required. Pessimistic constraint (allow minor version modify)
        }
    }

    required_version = ">= 1.5.0" # Minimum version of Terraform required.

}

# Configuration of the AWS provider
provider "aws" {
    region = var.region # AWS region where the resources will be created.
    # Configuration of the provider (not necessary if the file ~/.aws/credentials is already configured)
}

# Random suffix for unique resource names.
resource "random_id" "suffix" {
  byte_length = 4   
  
}