import boto3
import json

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-datastore')

def lambda_handler(event, context):
    response = table.get_item(
        Key={
            'Id': '1'
        }
    )
    item = response['Item']['Views']
    print(item)
    return item
