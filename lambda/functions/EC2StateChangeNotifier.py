import json
import http.client

SLACK_WEBHOOK_URL = ###REPLACE_ME####
SLACK_HOST = "hooks.slack.com"
SLACK_CHANNEL = "alerts"  

def lambda_handler(event, context):
    # Log the incoming event for debugging
    
    print(f"Received event: {json.dumps(event)}")  # {{ edit_1 }}

    # Extract the SNS message from the event
    records = event.get('Records', [])
    if records:
        sns_message = records[0].get('Sns', {}).get('Message', '{}')
        detail = json.loads(sns_message).get('detail', {})  # {{ edit_2 }}
    else:
        detail = {}

    instance_id = detail.get('instance-id')
    state = detail.get('state')

    # Construct the message to be sent to Slack
    message = {
        "text": f"EC2 Instance State Change:\nInstance ID: {instance_id}\nNew State: {state}",
        "channel": SLACK_CHANNEL  # {{ edit_3 }}
    }

    # Convert the message to JSON
    message_json = json.dumps(message)

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
