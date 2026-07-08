import json
import os
import logging
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
dynamodb_resource = boto3.resource('dynamodb')

# Fetch target resource names from environment variables
S3_BUCKET = os.environ.get('S3_BUCKET_NAME')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE_NAME')

def handler(event, context):
    """
    AWS Lambda handler triggered by SQS events.
    Processes batches of messages, logs metadata to DynamoDB, and saves payloads to S3.
    """
    logger.info(f"Received event batch with {len(event.get('Records', []))} records.")
    
    # Track execution status
    failed_message_ids = []
    
    table = dynamodb_resource.Table(DYNAMODB_TABLE)
    
    for record in event.get('Records', []):
        message_id = record.get('messageId')
        receipt_handle = record.get('receiptHandle')
        body = record.get('body', '')
        
        logger.info(f"Processing message ID: {message_id}")
        
        try:
            # 1. Parse payload structure (Strict validation)
            try:
                payload = json.loads(body)
            except json.JSONDecodeError as je:
                logger.error(f"Malformed JSON payload in message {message_id}: {str(je)}")
                # If JSON is invalid, throw to trigger DLQ routing
                raise ValueError("Message body is not valid JSON")
            
            # 2. Write payload to S3 bucket
            s3_key = f"processed/{datetime.utcnow().strftime('%Y/%m/%d')}/{message_id}.json"
            logger.info(f"Uploading payload to S3: s3://{S3_BUCKET}/{s3_key}")
            
            s3_client.put_object(
                Bucket=S3_BUCKET,
                Key=s3_key,
                Body=json.dumps(payload, indent=2),
                ContentType='application/json'
            )
            
            # 3. Write metadata to DynamoDB
            s3_uri = f"s3://{S3_BUCKET}/{s3_key}"
            timestamp = datetime.utcnow().isoformat()
            
            logger.info(f"Logging metadata to DynamoDB table {DYNAMODB_TABLE}")
            table.put_item(
                Item={
                    'message_id': message_id,
                    'timestamp': timestamp,
                    'status': 'PROCESSED',
                    's3_uri': s3_uri,
                    'payload_size_bytes': len(body)
                }
            )
            
            logger.info(f"Successfully processed message {message_id}")
            
        except Exception as e:
            logger.error(f"Failed to process message {message_id}. Error: {str(e)}")
            # In SQS-Lambda integrations, if we throw an exception,
            # the entire batch (or specific records) is returned to the queue.
            # We track failed message IDs to return them in batch response (partial batch response support).
            failed_message_ids.append({"itemIdentifier": message_id})
            
    # Return batch failure items to SQS so only failed items are retried
    # (Requires "ReportBatchItemFailures" enabled on SQS event source mapping)
    return {"batchItemFailures": failed_message_ids}
