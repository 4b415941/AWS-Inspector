# AWS Monitoring Script

This Bash script is designed for monitoring various AWS resources such as EC2 instances, RDS instances, S3 buckets, Elastic Beanstalk applications, CloudFront distributions, VPCs, IAM entities, and AWS Shield protection status. It collects metrics and checks the status of these resources, sending notifications via SNS in case of any issues.

## Features

- **Flexible Configuration**: AWS CLI profile and region can be configured using environment variables.
- **Email Notifications**: Sends email notifications via SNS in case of any alerts.
- **Logging**: Logs events to a log file for auditing and debugging purposes.
- **Automated Log Rotation**: Rotates log files to prevent them from growing too large.
- **Threshold Monitoring**: Monitors CPU and RAM usage of EC2 instances and triggers alerts if thresholds are exceeded.
- **Parallel Processing**: Utilizes parallel processing to monitor EC2 instances concurrently, enhancing performance.
- **User Interaction**: Provides a menu for selecting which AWS service to monitor and prompts for necessary inputs.

## Prerequisites

- AWS CLI installed and configured with appropriate permissions.
- SNS topic ARN configured for sending notifications.

## Usage

1. Clone or download the script to your local machine.
2. Ensure the AWS CLI is properly configured.
3. Set up an SNS topic and configure the `SNS_TOPIC_ARN` variable in the script.
4. Customize the email recipient address if necessary (`RECIPIENT_EMAIL` variable).
5. Run the script using Bash: `bash aws_monitoring.sh`.

## Configuration

- **AWS Profile**: Set the `AWS_PROFILE` environment variable to specify the AWS CLI profile to use.
- **AWS Region**: Set the `AWS_REGION` environment variable to specify the AWS region.
- **Threshold**: Adjust the `THRESHOLD` variable to set the CPU and RAM usage threshold for triggering alerts.

