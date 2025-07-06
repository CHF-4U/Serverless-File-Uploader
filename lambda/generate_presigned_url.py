import json
import boto3
import os
import uuid

s3 = boto3.client('s3')

def lambda_handler(event, context):
    bucket = os.environ.get("UPLOAD_BUCKET", "YOUR BUCKET NAME")
    key = f"uploads/{uuid.uuid4()}"
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",                 # Allow all origins or specify your domain
        "Access-Control-Allow-Headers": "Authorization,Content-Type",
        "Access-Control-Allow-Methods": "POST,OPTIONS"
    }

    try:
        url = s3.generate_presigned_url('put_object',
            Params={'Bucket': bucket, 'Key': key},
            ExpiresIn=3600)
        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({"upload_url": url, "file_key": key})
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": str(e)})
        }
