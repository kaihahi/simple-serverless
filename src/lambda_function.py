import json
import boto3
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('memo_table2')

def lambda_handler(event, context):
    body = json.loads(event['body'])
    memo = body['memo']

    item = {
        "id": str(uuid.uuid4()),
        "memo": memo
    }

    table.put_item(Item=item)

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "saved"})
    }
