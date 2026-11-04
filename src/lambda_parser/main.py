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
    raise ValueError("Variabile GEMINI_API_KEY non configurata o mancante.")

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
        raise ValueError(f"Formato file non supportato: {ext}")

# Function to evaluate a candidate's CV against a job description using the Gemini API.
def evaluate_candidate(cv_text: str, job_description: str) -> dict:
    
    prompt = f"""
    You are an expert ATS (Applicant Tracking System) software. Your task is to evaluate the alignment between the provided Candidate CV and the Job Description.
    
    JOB DESCRIPTION:
    {job_description}
    
    CV CANDIDATE:
    {cv_text}
    
    EVALUATION CRITERIA FOR THE SCORE (0-100):
    The 'score' MUST strictly represent the overall suitability of the candidate FOR THIS SPECIFIC JOB DESCRIPTION, evaluating three main dimensions:
    1. Technical Alignment: Intersection of required versus possessed technical skills.
    2. Seniority and Past Roles: Alignment of the candidate's past job titles, responsibilities, and total years of experience with the level required by the role.
    3. Career Progression: Evidence of professional growth, continuous learning, and increasing impact over time.
    
    Scoring Scale:
    - 0-30: Lacks fundamental requirements, irrelevant past roles, or insufficient career maturity for the position.
    - 31-60: Partial skill match, but career progression, past roles, or seniority do not fully align with the role's expectations.
    - 61-80: Strong match in core skills, highly relevant past roles, and a demonstrated career growth consistent with the position.
    - 81-100: Exceptional match; skills, past leadership/roles, and career trajectory perfectly align with or exceed all expectations.
    
    Respond only with a JSON structure as follows, without any markdown formatting, backticks, or prologue:
    {{
      "candidate_id": "Extract email. If missing, generate a unique string based on the name plus a random UUID.",
      "full_name": "Extract Name and Surname",
      "email": "Extract email address",
      "phone": "Extract phone number if present, otherwise empty string",
      "score": <INTEGER_VALUE>,
      "matching_skills": ["List of core technical skills present in BOTH the CV and Job Description"],
      "missing_skills": ["List of core technical skills required by the Job Description but NOT found in the CV"],
      "career_evaluation": "Briefly analyze the candidate's past roles, total experience, and professional growth trajectory.",
      "justification": "Explain the exact reason for the assigned score, weighing skills, seniority, and career progression."
    }}

    It's crucial that the response(description) is in Italian.
    """
    
    # Lista di modelli da provare in ordine di priorità
    fallback_models = [
        'gemini-3.8-flash',
        'gemini-3.6-flash',
        'gemini-3.5-flash-lite',
        'gemini-3.1-flash-lite',
        'gemini-3.1-pro-preview'
    ]
    
    last_exception = None
    
    for model_id in fallback_models:
        try:
            print(f"Tentativo di generazione con il modello: {model_id}")
            response = gemini_client.models.generate_content(
                model=model_id,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json"
                )
            )
            print(f"Successo! Utilizzato il modello: {model_id}")
            return json.loads(response.text)
            
        except Exception as e:
            print(f"Fallimento con {model_id}: {str(e)}")
            last_exception = e
            continue # Passa automaticamente al modello successivo nella lista
            
    # Se il ciclo finisce senza successi, solleva l'ultimo errore riscontrato
    raise RuntimeError(f"Tutti i modelli di fallback sono falliti. Ultimo errore: {str(last_exception)}")

def lambda_handler(event, context):
    candidates_table = dynamodb.Table(os.environ['CANDIDATES_TABLE'])
    jobs_table = dynamodb.Table(os.environ['JOBS_TABLE'])
    archive_bucket = os.environ['ARCHIVE_BUCKET']

    '''
    An example of the event structure received by the Lambda function when triggered by an SQS message containing an S3 event notification is as follows:
    {
    "Records": [
        {
        "messageId": "19dd0b57-b21e-4ac1-bd88-01bbb068cb78",
        "receiptHandle": "MessageReceiptHandle",
        "body": "{\"Records\":[
                                {\"eventVersion\":\"2.1\",
                                \"eventSource\":\"aws:s3\",
                                \"awsRegion\":\"eu-west-1\",
                                \"eventTime\":\"2026-11-04T11:34:00.000Z\",
                                \"eventName\":\"ObjectCreated:Put\",
                                \"s3\":{\"bucket\":{\"name\":\"cv-incoming-bucket\"},
                                                    \"object\":{\"key\":\"jobs/JOB-DEV-2026/mario_rossi.pdf\",
                                                    \"size\":1024}}}]}",
        "attributes": {
            "ApproximateReceiveCount": "1",
            "SentTimestamp": "1730716440000",
            "SenderId": "AIDAIT2UOQQY3AUEKVGXU",
            "ApproximateFirstReceiveTimestamp": "1730716440010"
        },
        "messageAttributes": {},
        "md5OfBody": "7b270e59b47ff90a553787216d55d91d",
        "eventSource": "aws:sqs",
        "eventSourceARN": "arn:aws:sqs:eu-west-1:123456789012:cv-processing-queue",
        "awsRegion": "eu-west-1"
        }
    ]
    }
    '''
    for sqs_record in event.get('Records', []):
        s3_event = json.loads(sqs_record['body'])
        
        for s3_record in s3_event.get('Records', []):
            source_bucket = s3_record['s3']['bucket']['name']
            object_key = urllib.parse.unquote_plus(s3_record['s3']['object']['key'])
            
            path_parts = object_key.split('/')
            job_id = path_parts[1] if len(path_parts) > 1 else "GENERIC"
            
            job_response = jobs_table.get_item(Key={'job_id': job_id})
            job_desc = job_response.get('Item', {}).get('description', 'Valutazione generica')

            # Download the CV file from S3 to the Lambda's temporary storage, extract its text, evaluate it against the job description, and store the results in DynamoDB. 
            file_name = os.path.basename(object_key)
            ext = os.path.splitext(file_name)[1]
            local_path = f"/tmp/{file_name}"
            
            s3_client.download_file(source_bucket, object_key, local_path)
            cv_text = extract_text(local_path, ext)
            
            evaluation = evaluate_candidate(cv_text, job_desc)
            item = {
                'CandidateID': evaluation.get('candidate_id', file_name),
                'job_id': job_id,
                'score': int(evaluation.get('score', 0)),
                'full_name': evaluation.get('full_name', ''),
                'email': evaluation.get('email', ''),
                'matching_skills': evaluation.get('matching_skills', []),
                'missing_skills': evaluation.get('missing_skills', []),
                'justification': evaluation.get('justification', ''),
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