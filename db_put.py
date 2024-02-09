import boto3
import json

# Get the service resource.
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-datastore')

def lambda_handler(event, context):
    response = table.get_item(
        Key={
            'Id': '1'
        }
    )
    views = response['Item']['Views']
    views += 1
    print(views)
    response = table.put_item(
        Item={
            'Id': '1',
            'Views': views
        }
    )
    return views
    