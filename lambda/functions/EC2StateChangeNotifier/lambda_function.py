import json
import http.client
import boto3

from botocore.exceptions import ClientError

SLACK_HOST = "hooks.slack.com"
SLACK_CHANNEL = "alerts"  

def lambda_handler(event, context):
    # Log the incoming event for debugging
    
    print(f"Received event: {json.dumps(event)}")

    # Extract the SNS message from the event
    records = event.get('Records', [])
    if records:
        sns_message = records[0].get('Sns', {}).get('Message', '{}')
        detail = json.loads(sns_message).get('detail', {})
    else:
        detail = {}

    instance_id = detail.get('instance-id')
    state = detail.get('state')

    # Construct the message to be sent to Slack
    message = {
        "text": f"EC2 Instance State Change:\nInstance ID: {instance_id}\nNew State: {state}",
        "channel": SLACK_CHANNEL 
    }

    # Convert the message to JSON
    message_json = json.dumps(message)

    # Read the webhook URL from environment
    SLACK_WEBHOOK_URL = get_secret()
    # Parse the webhook URL to get the path
    webhook_path = "/services" + SLACK_WEBHOOK_URL.split("/services")[1]

    # Create an HTTP connection
    conn = http.client.HTTPSConnection(SLACK_HOST)

    # Send the POST request
    headers = {'Content-Type': 'application/json'}
    conn.request("POST", webhook_path, body=message_json, headers=headers)

    # Get the response from Slack
    response = conn.getresponse()
    response_body = response.read().decode()

    # Close the connection
    conn.close()

    # Log the response from Slack
    print(f"Slack response: {response_body}")
    print(f"Event: {event}")

    return {
        'statusCode': 200,
        'body': json.dumps('Notification sent to Slack!')
    }

def get_secret():

    secret_name = "kodify/webhook_url"
    region_name = "eu-north-1"

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e

    return get_secret_value_response['SecretString']