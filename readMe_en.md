# ATS Cloud Platform - Serverless AI-Driven Recruitment System

A **Serverless Event-Driven** platform for the ingestion, parsing, and automated ranking of Curriculum Vitae, based on **AWS** infrastructure and advanced **Google Gemini** language models.

---

## System Architecture

The infrastructure is fully managed as code through **Terraform** and consists of the following layers:

1. **API & Interface Layer:** Amazon API Gateway (HTTP API) managed by an AWS Lambda proxy function (`lambda_api`) for RESTful interaction (Base64 CV upload, job posting, and generation of pre-signed URLs for the secure viewing of files).
2. **Ingestion & Buffering Layer:** Amazon S3 (`cv-incoming-bucket`) for the temporary staging of documents and Amazon SQS (`cv-processing-queue`) for asynchronous processing decoupling, supported by a Dead Letter Queue (`cv-dlq`).
3. **Compute & AI Layer:** AWS Lambda (`lambda_parser`) for text extraction (via `pypdf`) and profile classification/scoring through the Google Gemini APIs.
4. **Persistence & Archive Layer:** Amazon DynamoDB (`jobs_table` and `candidates_table` with GSI `JobIdScoreIndex`) for NoSQL persistence and Amazon S3 (`cv-archive-bucket`) for the secure long-term storage of valid CVs.

---

## Project Structure

```text
Progetto_dir/
├── src/
│   ├── lambda_api/
│   │   └── main.py              # REST API backend (Jobs, Candidates, Base64 Upload)
│   ├── lambda_parser/
│   │   └── main.py              # Asynchronous SQS parser + Google Gemini API invocation
│   └── layers/
│       ├── python/              # Build directory for Python dependencies (Git-Ignored)
│       └── dependencies.zip     # Packaged layer for the Lambda Linux environment
│
├── test_cv/                     # Data set for validation and testing (Job Descriptions and PDFs)
├── venv/                        
│
├── .gitignore                   
├── .terraform.lock.hcl          # Terraform provider lock file (Git-Ignored)
├── app.html                     # Frontend graphical interface (Single-Page Application)
├── dynamodb.tf                  # DynamoDB tables and GSI indexes definition
├── gateway.tf                   # API Gateway endpoints and integrations definition
├── iam.tf                       # IAM security roles and policies (Least Privilege)
├── lambda.tf                    # Lambda functions deployment and Event Source Mapping
├── main.tf                      # AWS provider and Terraform backend configuration
├── outputs.tf                   # Infrastructure outputs (API URL, Bucket Names)
├── readMe.md                    # Project documentation
├── requirements.txt             # Project Python dependencies
├── s3.tf                        # S3 bucket configuration (Incoming and Archive)
├── sqs.tf                       # SQS queue, DLQ, and Visibility Timeout configuration
├── terraform.tfvars             # API Key (Git-Ignored)
├── config.js                    # API URL (Git-Ignored)
└── variables.tf                 # Terraform variables declaration
```

> **Build Artifacts Note:** Compressed `.zip` files (`lambda_api.zip`, `lambda_parser.zip`, `dependencies.zip`) are excluded from Git tracking (`.gitignore`). They must be generated locally before running Terraform, as described in the guide below.

---

## Prerequisites

Make sure you have the following tools installed and configured in your local environment:

* [AWS CLI](https://aws.amazon.com/cli/) (configured with IAM credentials with suitable permissions via `aws configure`).
* [Terraform](https://www.terraform.io/) (v1.0.0+).
* [Python 3.11](https://www.python.org/).
* A valid **Google Gemini API Key** (available from [Google AI Studio](https://aistudio.google.com/)).

---

## Installation and Deployment Guide

### 1. Clone the repository
```bash
git clone <repository-url>
cd ATS_Cloud_Platform
```

### 2. Configure environment variables (`terraform.tfvars`)
Create the `terraform.tfvars` file (or edit the `terraafomr.tfvars.example` file) in the project root and enter your Google Gemini API Key and the desired AWS region:

```hcl
aws_region     = "eu-north-1"
gemini_api_key = "AIzaSyYourActualGeminiApiKeyHere..."
```

### 3. Build the Lambda Layer (Cross-Compilation for Linux x86_64)
To avoid binary compatibility issues in the Linux micro-VM used by AWS Lambda when running on macOS/Windows systems, compile and extract binary packages compatible with Linux:

```bash
# 1. Clean the local environment
rm -rf src/layers/python layer_mac.zip
mkdir -p src/layers/python

# 2. Download native Linux manylinux2014_x86_64 binaries
pip install \
  --platform manylinux2014_x86_64 \
  --target ./src/layers/python \
  --implementation cp \
  --python-version 3.11 \
  --only-binary=:all: \
  --no-cache-dir \
  -r requirements.txt

# 3. Package the layer while preserving the python/ root directory
cd src/layers
zip -r ../../src/layers/dependencies.zip python
cd ../..
```

### 4. Initialize and apply the infrastructure with Terraform
```bash
# Initialize Terraform providers
terraform init

# Verify the execution plan
terraform plan

# Apply and create the resources on AWS
terraform apply -auto-approve
```

After the application is complete, Terraform will return the API Gateway endpoint in the output, for example:
`api_endpoint = "https://xxxxxxxxx.execute-api.eu-north-1.amazonaws.com"`

This URL must be entered in a `config.js` file (or by editing the `config.js.example` file) in the project root.

---

## Application Testing

The `test_cv/` directory contains the material required for functional testing of the entire system.

### Step 1: Configure the Web Frontend (`app.html`)
1. Open the `app.html` file with a text editor.
2. Locate the `API_BASE_URL` constant in the `config.js` file and update it with the URL generated by Terraform:
   ```javascript
   const API_BASE_URL = "https://xxxxxxxxx.execute-api.eu-north-1.amazonaws.com";
   ```
3. Open the `app.html` file in any web browser.

### Step 2: Publish a Job Position (Recruiter Area)
1. In the **Recruiter Area**, enter a title (e.g. `Senior Cloud Engineer`).
2. Open the text file containing the Job Description text in `test_cv/` (or paste the position's descriptive requirements).
3. Click **Publish Job Description**. A unique `job_id` will be generated and stored in DynamoDB.

### Step 3: Submit Resumes (Candidate Area)
1. In the **Candidate Area**, select the created position from the drop-down menu.
2. Upload one of the PDFs in the `test_cv/` directory:
   * **Relevant CV Test:** Select a PDF containing a CV relevant to the Job Description.
   * **Non-CV Document Test:** Upload an unrelated file (e.g. an invoice, a form, or random text).
3. Click **Submit Application**.

### Step 4: Verify Automated Parsing and Ranking
1. Return to the Recruiter Area and click the **Candidates** button next to the created position.
2. **Valid CV Result:** The system will display the ranking with the score (Score out of 100), identified skills, deficiencies, and the **Open PDF** button, which generates a Presigned URL for secure access to the document stored in the archive bucket.
3. **Non-CV Document Result:** The document rejected by the LLM is automatically removed from the `cv-incoming-bucket` without being added to the ranking or archived in S3.

---

## Infrastructure Teardown

To completely remove all resources created on AWS and avoid unwanted charges:

```bash
terraform destroy -auto-approve
```
