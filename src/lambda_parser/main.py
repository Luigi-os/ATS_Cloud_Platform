import json
import os
import urllib.parse
import boto3
from pypdf import PdfReader
from google import genai
from google.genai import types


# Initialize AWS clients for S3 and DynamoDB as global variables to be reused across Lambda invocations. (Warm start optimization)
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# Initialize the Gemini API client using the API key from environment variables. Raise an error if the key is not set.
# Retrieve the Gemini API key from environment variables, because after the apply the key is stored in AWS Lambda environment variables.
api_key = os.environ.get("GEMINI_API_KEY")
if not api_key:
    raise ValueError("GEMINI_API_KEY is not set.")

gemini_client = genai.Client(api_key=api_key)

# Function to extract text from different file formats (PDF, DOCX, TXT).
def extract_text(file_path: str, ext: str) -> str:
    ext = ext.lower()
    if ext == '.pdf':
        reader = PdfReader(file_path)
        # Extract text from each page and join them with newlines, filtering out empty pages.
        return "\n".join([page.extract_text() for page in reader.pages if page.extract_text()])
    elif ext == '.txt':
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            return f.read()
    else:
        raise ValueError(f"File not supported: {ext}")

# Function to evaluate a candidate's CV against a job description using the Gemini API.
# The function defines a prompt that instructs the model to determine if the document is a valid CV and to evaluate its alignment with the job description.
def evaluate_candidate(cv_text: str, job_description: str) -> dict:
    
    prompt = f"""
    You are an expert ATS (Applicant Tracking System) software. Your task is to evaluate the alignment between the provided Candidate CV and the Job Description.
    First, verify if the provided text is actually a professional Resume / Curriculum Vitae (CV).
    
    JOB DESCRIPTION:
    {job_description}
    
    DOCUMENT TEXT:
    {cv_text}
    
    INSTRUCTIONS:
    - If the document is NOT a valid CV (e.g. invoice, book chapter, cover letter only, random text, identity document):
      Set "is_cv" to false, "score" to null, and leave all other evaluation fields as null or empty lists.
    - If the document IS a valid CV:
      Set "is_cv" to true, evaluate the alignment with the Job Description, and populate the fields accordingly.
    
    Respond strictly with the following JSON structure without markdown formatting or backticks:
    {{
      "is_cv": true,
      "candidate_id": "Extract email or generate unique string",
      "full_name": "Extract Name and Surname or null",
      "email": "Extract email or null",
      "phone": "Extract phone or null",
      "score": null,
      "matching_skills": [],
      "missing_skills": [],
      "career_evaluation": "Analysis or explanation of invalid document",
      "justification": "Justification of score or reason why document is not a CV"
    }}

    It's crucial that the response(description) is in Italian.
    """
    
    # List of fallback models to try in case the primary model fails. The models are ordered from most capable to least capable.
    fallback_models = [
        'gemini-3.8-flash',
        'gemini-3.6-flash',
        'gemini-3.5-flash-lite',
        'gemini-3.1-flash-lite',
        'gemini-3.1-pro-preview'
    ]

    # If all models fail, raise an exception with the last encountered error.
    last_exception = None

    # Call Gemini API with fallback mechanism.
    for model_id in fallback_models:
        try:
            print(f"Trying to generate content with model: {model_id}")
            response = gemini_client.models.generate_content(
                model=model_id,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json"
                )
            )
            print(f"Success! The model used was: {model_id}")
            return json.loads(response.text)
            
        except Exception as e:
            print(f"Failed to generate content with {model_id}: {str(e)}")
            last_exception = e
            continue # Passa automaticamente al modello successivo nella lista
            
    # Se il ciclo finisce senza successi, solleva l'ultimo errore riscontrato
    raise RuntimeError(f"All the fallback models failed, last error: {str(last_exception)}")

# The handler function processes incoming SQS messages, extracts CVs from S3, evaluates them against job descriptions, and stores the results in DynamoDB.
# It also handles moving valid CVs to an archive bucket and deleting invalid ones.
def lambda_handler(event, context):
    candidates_table = dynamodb.Table(os.environ['CANDIDATES_TABLE'])
    jobs_table = dynamodb.Table(os.environ['JOBS_TABLE'])
    archive_bucket = os.environ['ARCHIVE_BUCKET']

    for sqs_record in event.get('Records', []):
        s3_event = json.loads(sqs_record['body'])
        
        for s3_record in s3_event.get('Records', []):
            source_bucket = s3_record['s3']['bucket']['name']
            object_key = urllib.parse.unquote_plus(s3_record['s3']['object']['key'])
            
            path_parts = object_key.split('/')
            job_id = path_parts[1] if len(path_parts) > 1 else "GENERIC"
            
            job_response = jobs_table.get_item(Key={'job_id': job_id})
            job_desc = job_response.get('Item', {}).get('description', 'Valutazione generica')

            file_name = os.path.basename(object_key)
            ext = os.path.splitext(file_name)[1]
            local_path = f"/tmp/{file_name}"
            
            s3_client.download_file(source_bucket, object_key, local_path)
            cv_text = extract_text(local_path, ext)
            
            evaluation = evaluate_candidate(cv_text, job_desc)
            
            candidate_id = evaluation.get("candidate_id")
            if not candidate_id or candidate_id == "Extract email or generate unique string":
                candidate_id = evaluation.get("email") or file_name

            is_valid_cv = evaluation.get("is_cv", False)
            
            if not is_valid_cv:
                print(f"Documento non valido identificato e scartato: {object_key}")
                
                s3_client.delete_object(Bucket=source_bucket, Key=object_key)
                
                if os.path.exists(local_path):
                    os.remove(local_path)
                
                continue

            raw_score = evaluation.get('score')
            score = int(raw_score) if raw_score is not None else 0
            candidate_id = evaluation.get("candidate_id") or evaluation.get("email") or file_name

            item = {
                'CandidateID': candidate_id,
                'job_id': job_id,
                'is_cv': True,
                'status': 'PROCESSED',
                'full_name': evaluation.get('full_name'),
                'email': evaluation.get('email'),
                'phone': evaluation.get('phone'),
                'score': score,
                'matching_skills': evaluation.get('matching_skills', []),
                'missing_skills': evaluation.get('missing_skills', []),
                'career_evaluation': evaluation.get('career_evaluation'),
                'justification': evaluation.get('justification'),
                'archive_s3_uri': f"s3://{archive_bucket}/{object_key}"
            }

            candidates_table.put_item(Item=item)
            
            s3_client.copy_object(
                Bucket=archive_bucket,
                CopySource={'Bucket': source_bucket, 'Key': object_key},
                Key=object_key
            )
            
            s3_client.delete_object(Bucket=source_bucket, Key=object_key)
            
            if os.path.exists(local_path):
                os.remove(local_path)
                
    return {'statusCode': 200, 'body': json.dumps('Elaborazione completata')}