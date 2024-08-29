import boto3

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    # Replace 'instance-id' with your EC2 instance ID
    ec2.stop_instances(InstanceIds=['i-01ec09e9f3d85732a'])
    return 'EC2 Instance stopped'
