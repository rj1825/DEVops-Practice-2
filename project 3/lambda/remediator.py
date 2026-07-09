import json
import os
import logging
import boto3
from botocore.exceptions import ClientError

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
ec2_client = boto3.client('ec2')
sns_client = boto3.client('sns')

# Fetch target resources from environment variables
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

def send_security_alert(subject, message):
    """Utility function to publish security alerts to the SNS topic."""
    logger.info(f"Publishing security alert: {subject}")
    try:
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
    except ClientError as ce:
        logger.error(f"Failed to publish SNS alert: {str(ce)}")

def handle_s3_event(event_detail):
    """Analyzes and auto-remediates S3 buckets with public permissions."""
    bucket_name = event_detail.get('requestParameters', {}).get('bucketName')
    if not bucket_name:
        logger.warning("S3 event received but no bucketName found in requestParameters.")
        return

    logger.info(f"Auditing S3 bucket: {bucket_name}")
    
    try:
        # Check if block public access configuration is already fully locked down
        try:
            pab_config = s3_client.get_public_access_block(Bucket=bucket_name)
            config = pab_config.get('PublicAccessBlockConfiguration', {})
            is_secure = (
                config.get('BlockPublicAcls') == True and
                config.get('IgnorePublicAcls') == True and
                config.get('BlockPublicPolicy') == True and
                config.get('RestrictPublicBuckets') == True
            )
        except ClientError as ce:
            # If get_public_access_block returns NoSuchPublicAccessBlockConfiguration (404), it means no block exists.
            is_secure = False

        if not is_secure:
            logger.warning(f"S3 Bucket {bucket_name} lacks full Block Public Access configurations! Remediating...")
            
            # Remediate: Force block all public access
            s3_client.put_public_access_block(
                Bucket=bucket_name,
                PublicAccessBlockConfiguration={
                    'BlockPublicAcls': True,
                    'IgnorePublicAcls': True,
                    'BlockPublicPolicy': True,
                    'RestrictPublicBuckets': True
                }
            )
            
            alert_subject = f"⚠️ [SECURITY AUTO-REMEDIATION] S3 Public Block Enabled: {bucket_name}"
            alert_message = (
                f"Time: {event_detail.get('eventTime')}\n"
                f"AWS Account: {event_detail.get('userIdentity', {}).get('accountId')}\n"
                f"Actor: {event_detail.get('userIdentity', {}).get('arn')}\n"
                f"Event Action: {event_detail.get('eventName')}\n\n"
                f"Vulnerability: S3 Bucket '{bucket_name}' was configured to allow public access or created without Public Access Blocks.\n"
                f"Remediation Action: Enabled 'Block Public Access' (Blocked all public ACLs and Bucket Policies) instantly via AWS Lambda remediator."
            )
            send_security_alert(alert_subject, alert_message)
        else:
            logger.info(f"S3 Bucket {bucket_name} is already compliant.")

    except ClientError as e:
        logger.error(f"Error handling S3 bucket {bucket_name}: {str(e)}")

def handle_sg_event(event_detail):
    """Analyzes and auto-remediates Security Groups with open SSH (Port 22)."""
    request_params = event_detail.get('requestParameters', {})
    group_id = request_params.get('groupId')
    
    # AuthorizeSecurityGroupIngress has rules inside 'ipPermissions'
    ip_permissions = request_params.get('ipPermissions', {}).get('items', [])
    
    if not group_id or not ip_permissions:
        logger.info("EC2 event received but no security group ID or permissions found.")
        return

    logger.info(f"Auditing Security Group: {group_id}")
    violating_permissions = []

    # Scan for SSH open to world (Port 22, Protocol TCP, Ingress CIDR 0.0.0.0/0)
    for permission in ip_permissions:
        from_port = permission.get('fromPort')
        to_port = permission.get('toPort')
        ip_protocol = permission.get('ipProtocol')
        ip_ranges = permission.get('ipRanges', {}).get('items', [])

        # Check if SSH port (22) is open (or matches port range)
        is_ssh = (ip_protocol == 'tcp' or ip_protocol == '-1') and (
            (from_port <= 22 <= to_port) if (from_port is not None and to_port is not None) else (from_port == 22 or from_port is None)
        )

        if is_ssh:
            for ip_range in ip_ranges:
                cidr = ip_range.get('cidrIp')
                if cidr == '0.0.0.0/0':
                    # Save violating permission format to revoke it
                    violating_permissions.append({
                        'IpProtocol': ip_protocol,
                        'FromPort': from_port if from_port is not None else 22,
                        'ToPort': to_port if to_port is not None else 22,
                        'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                    })

    if violating_permissions:
        logger.warning(f"Vulnerability found in Security Group {group_id}! Open SSH (0.0.0.0/0) detected. Remediating...")
        try:
            # Remediate: Revoke the insecure ingress rules
            ec2_client.revoke_security_group_ingress(
                GroupId=group_id,
                IpPermissions=violating_permissions
            )
            
            alert_subject = f"⚠️ [SECURITY AUTO-REMEDIATION] SSH Revoked in SG: {group_id}"
            alert_message = (
                f"Time: {event_detail.get('eventTime')}\n"
                f"AWS Account: {event_detail.get('userIdentity', {}).get('accountId')}\n"
                f"Actor: {event_detail.get('userIdentity', {}).get('arn')}\n"
                f"Event Action: {event_detail.get('eventName')}\n\n"
                f"Vulnerability: Security Group '{group_id}' was configured with SSH (Port 22) open to the world (0.0.0.0/0).\n"
                f"Remediation Action: Revoked the violating ingress rule instantly via AWS Lambda remediator."
            )
            send_security_alert(alert_subject, alert_message)
        except ClientError as ce:
            logger.error(f"Failed to revoke security group rule for {group_id}: {str(ce)}")

def handler(event, context):
    """Main Lambda handler triggered by EventBridge."""
    logger.info(f"Security Remediator triggered by event: {json.dumps(event)}")
    
    # EventBridge routes CloudTrail events inside the 'detail' object
    detail = event.get('detail', {})
    event_source = detail.get('eventSource')
    event_name = detail.get('eventName')
    
    logger.info(f"Event Source: {event_source}, Event Name: {event_name}")
    
    if event_source == 's3.amazonaws.com':
        handle_s3_event(detail)
    elif event_source == 'ec2.amazonaws.com':
        handle_sg_event(detail)
    else:
        logger.warning(f"Unsupported event source: {event_source}")
        
    return {"status": "COMPLETE"}
