# This is the main Lambda function that serves as the backend for the API Gateway.
#  It handles requests related to job postings and generates presigned URLs for file uploads to S3.
import json
import os
import boto3
import uuid
import base64
import traceback
from decimal import Decimal
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')

def decimal_default(obj):
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    raise TypeError

def lambda_handler(event, context):
    raw_path = event.get('rawPath') or event.get('path') or ''
    path = raw_path.rstrip('/')
    if not path:
        path = '/'
    
    request_context = event.get('requestContext', {})
    http_info = request_context.get('http', {})
    method = (http_info.get('method') or event.get('httpMethod') or '').upper()
    
    path_params = event.get('pathParameters') or {}
    job_id_param = path_params.get('job_id')
    
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS"
    }

    try:
        jobs_table = dynamodb.Table(os.environ['JOBS_TABLE'])
        candidates_table = dynamodb.Table(os.environ['CANDIDATES_TABLE'])

        if path == '/jobs' and method == 'GET':
            response = jobs_table.scan()
            jobs = response.get('Items', [])
            return {'statusCode': 200, 'headers': headers, 'body': json.dumps(jobs, default=decimal_default)}

        elif method == 'GET' and '/candidates' in path:
            target_job_id = job_id_param or path.split('/')[2]
            
            response = candidates_table.query(
                IndexName='JobIdScoreIndex',
                KeyConditionExpression=Key('job_id').eq(target_job_id),
                ScanIndexForward=False
            )
            
            candidates = response.get('Items', [])

            # Estrazione dei presigned URL per i CV archiviati in S3
            for item in candidates:
                s3_uri = item.get('archive_s3_uri', '')
                if s3_uri.startswith('s3://'):
                    # Estrae nome del bucket e chiave dell'oggetto dall'URI
                    uri_parts = s3_uri.replace('s3://', '').split('/', 1)
                    bucket_name = uri_parts[0]
                    object_key = uri_parts[1]
                    
                    # Genera un URL temporaneo valido per 1 ora (3600 secondi)
                    presigned_url = s3_client.generate_presigned_url(
                        'get_object',
                        Params={'Bucket': bucket_name, 'Key': object_key},
                        ExpiresIn=3600
                    )
                    item['cv_url'] = presigned_url
                else:
                    item['cv_url'] = None

            return {'statusCode': 200, 'headers': headers, 'body': json.dumps(candidates, default=decimal_default)}

        elif path == '/jobs' and method == 'POST':
            raw_body = event.get('body') or '{}'
            body = json.loads(raw_body)
            title = body.get('title')
            description = body.get('description')
            
            if not title or not description:
                return {'statusCode': 400, 'headers': headers, 'body': json.dumps({'error': 'Titolo e descrizione obbligatori'})}
                
            job_id = f"JOB-{str(uuid.uuid4())[:8].upper()}"
            
            jobs_table.put_item(Item={
                'job_id': job_id,
                'title': title,
                'description': description
            })
            
            return {'statusCode': 201, 'headers': headers, 'body': json.dumps({'message': 'Posizione creata', 'job_id': job_id})}

        elif method == 'DELETE' and (job_id_param or path.startswith('/jobs/')):
            target_job_id = job_id_param or path.split('/')[-1]
            jobs_table.delete_item(Key={'job_id': target_job_id})
            return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'message': 'Posizione eliminata', 'job_id': target_job_id})}

        elif path == '/upload' and method == 'POST':
            raw_body = event.get('body') or '{}'
            body = json.loads(raw_body)
            job_id = body.get('job_id')
            file_name = body.get('file_name')
            file_base64 = body.get('file_base64')
            
            if not job_id or not file_name or not file_base64:
                return {'statusCode': 400, 'headers': headers, 'body': json.dumps({'error': 'Parametri mancanti'})}
                
            object_key = f"jobs/{job_id}/{file_name}"
            bucket_name = os.environ['INCOMING_BUCKET']
            
            # Decodifica il file da Base64 ed esegue il caricamento tramite boto3
            file_bytes = base64.b64decode(file_base64)
            
            s3_client.put_object(
                Bucket=bucket_name,
                Key=object_key,
                Body=file_bytes
            )
            
            return {
                'statusCode': 200, 
                'headers': headers, 
                'body': json.dumps({
                    'message': 'File caricato con successo su S3',
                    'key': object_key
                })
            }
            
        else:
            return {'statusCode': 404, 'headers': headers, 'body': json.dumps({'error': 'Not Found'})}
            
    except Exception as e:
        return {
            'statusCode': 500, 
            'headers': headers, 
            'body': json.dumps({
                'error_type': type(e).__name__,
                'error_message': str(e),
                'traceback': traceback.format_exc()
            })
        }