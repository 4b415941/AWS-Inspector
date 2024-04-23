#!/bin/bash

# Author: Kadircan Kaya
# LinkedIn: [Kadircan Kaya](https://www.linkedin.com/in/kadircan-kaya/)

# AWS CLI configuration
AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-west-2}"

# Email notification variables
RECIPIENT_EMAIL="your-email@example.com"
EMAIL_SUBJECT="AWS Monitoring Alert"

# Log file
LOG_DIR="/var/log/aws_monitoring"
LOG_FILE="$LOG_DIR/monitoring_$(date +%Y-%m-%d_%H-%M-%S).log"

# Threshold for CPU and RAM usage
THRESHOLD=80

# Function to send notification via SNS
send_notification() {
    local message=$1
    aws sns publish --topic-arn "$SNS_TOPIC_ARN" --message "$message"
}

# Function to log events
log_event() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Automated Log Rotation
rotate_logs() {
    if [ -f "$LOG_FILE" ]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
        touch "$LOG_FILE"
    fi
}

# Function to monitor EC2 instance metrics
check_ec2_metrics() {
    local instance_id=$1
    local cpu_usage=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/EC2 \
        --metric-name CPUUtilization \
        --dimensions Name=InstanceId,Value=$instance_id \
        --start-time $(date -u +%Y-%m-%dT%TZ --date '1 hour ago') \
        --end-time $(date -u +%Y-%m-%dT%TZ) \
        --period 3600 \
        --statistics Maximum \
        --output text | awk '{print $2}'
    )
    local ram_usage=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/EC2 \
        --metric-name MemoryUtilization \
        --dimensions Name=InstanceId,Value=$instance_id \
        --start-time $(date -u +%Y-%m-%dT%TZ --date '1 hour ago') \
        --end-time $(date -u +%Y-%m-%dT%TZ) \
        --period 3600 \
        --statistics Maximum \
        --output text | awk '{print $2}'
    )
    
    log_event "Checking EC2 instance metrics for ID: $instance_id"
    
    if [ -z "$cpu_usage" ] || [ -z "$ram_usage" ]; then
        log_event "Error: Failed to retrieve metrics for EC2 instance $instance_id"
        return 1
    fi
    
    echo "EC2 Instance ID: $instance_id"
    echo "CPU Usage (Last Hour): $cpu_usage%"
    echo "RAM Usage (Last Hour): $ram_usage%"
    
    if (( $(echo "$cpu_usage > $THRESHOLD" | bc -l) )) || (( $(echo "$ram_usage > $THRESHOLD" | bc -l) )); then
        message="CPU or RAM usage threshold exceeded! EC2 Instance ID: $instance_id"
        send_notification "$message"
        log_event "$message"
        ssh -i your-ssh-key.pem ec2-user@$instance_id "uptime; free -m"
    fi
}

# Parallel Processing: Function to monitor EC2 instances concurrently
check_ec2_instances_parallel() {
    local instance_ids=$1
    local IFS=' ' read -r -a ids_array <<< "$instance_ids"
    
    for instance_id in "${ids_array[@]}"; do
        check_ec2_metrics "$instance_id" &
    done
    wait
}

# Function to monitor RDS instance status
check_rds_status() {
    local db_instance_identifier=$1
    local db_status=$(aws rds describe-db-instances \
        --db-instance-identifier $db_instance_identifier \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text
    )
    
    log_event "Checking RDS instance status for ID: $db_instance_identifier"
    
    echo "RDS Instance: $db_instance_identifier"
    echo "Status: $db_status"
    
    if [ "$db_status" != "available" ]; then
        message="RDS instance status: $db_instance_identifier status: $db_status"
        send_notification "$message"
        log_event "$message"
    fi
}

# Function to monitor S3 bucket storage usage
check_s3_storage_usage() {
    local bucket_name=$1
    local storage_usage=$(aws s3 ls s3://$bucket_name --recursive \
        | awk 'BEGIN {total=0} {total+=$3} END {print total}'
    )
    
    log_event "Checking S3 bucket storage usage for Bucket: $bucket_name"
    
    echo "S3 Bucket: $bucket_name"
    echo "Storage Usage: $storage_usage bytes"
    
    if [ -z "$storage_usage" ]; then
        log_event "Error: Failed to retrieve storage usage for S3 bucket $bucket_name"
        return 1
    fi
    
    if [ "$storage_usage" -gt 1000000000 ]; then
        message="S3 bucket storage usage threshold exceeded! Bucket: $bucket_name"
        send_notification "$message"
        log_event "$message"
    fi
}

# Function to monitor Elastic Beanstalk application status
check_beanstalk_status() {
    local app_name=$1
    local env_name=$2
    local env_status=$(aws elasticbeanstalk describe-environments \
        --application-name $app_name \
        --environment-names $env_name \
        --query 'Environments[0].Status' \
        --output text
    )
    
    log_event "Checking Elastic Beanstalk application status: $app_name, Environment: $env_name"
    
    echo "Elastic Beanstalk Application: $app_name, Environment: $env_name"
    echo "Status: $env_status"
    
    if [ "$env_status" != "Ready" ]; then
        message="Elastic Beanstalk application status: $app_name, environment: $env_name, status: $env_status"
        send_notification "$message"
        log_event "$message"
    fi
}

# Function to monitor CloudFront distribution status
check_cloudfront_status() {
    local distribution_id=$1
    local distribution_status=$(aws cloudfront get-distribution \
        --id $distribution_id \
        --query 'Distribution.Status' \
        --output text
    )
    
    log_event "Checking CloudFront distribution status for ID: $distribution_id"
    
    echo "CloudFront Distribution: $distribution_id"
    echo "Status: $distribution_status"
    
    if [ "$distribution_status" != "Deployed" ]; then
        message="CloudFront distribution status: $distribution_id, status: $distribution_status"
        send_notification "$message"
        log_event "$message"
    fi
}

# Function to monitor VPC status
check_vpc_status() {
    local vpc_id=$1
    local vpc_status=$(aws ec2 describe-vpcs \
        --vpc-ids $vpc_id \
        --query 'Vpcs[0].State' \
        --output text
    )
    
    log_event "Checking VPC status for ID: $vpc_id"
    
    echo "VPC ID: $vpc_id"
    echo "Status: $vpc_status"
}

# Function to monitor IAM entities status
check_iam_entities_status() {
    local entity_type=$1
    local entities=$(aws iam list-$entity_type \
        --query "${entity_type^}s[*].[${entity_type^}Name,${entity_type^}Id]" \
        --output text
    )
    
    log_event "Checking IAM $entity_type's status"
    
    echo "$entity_type's:"
    echo "$entities"
}

# Function to monitor AWS Shield protection status
check_shield_protection_status() {
    local protection_id=$1
    local protection_status=$(aws shield describe-protection \
        --protection-id $protection_id \
        --query 'Protection.Status' \
        --output text
    )
    
    log_event "Checking AWS Shield protection status for ID: $protection_id"
    
    echo "Protection ID: $protection_id"
    echo "Status: $protection_status"
}

# Main function to select and execute monitoring tasks
main() {
    echo "Select the service you want to monitor:"
    echo "1. EC2 Instances"
    echo "2. RDS Instances"
    echo "3. S3 Buckets"
    echo "4. Elastic Beanstalk Applications"
    echo "5. CloudFront Distributions"
    echo "6. VPC"
    echo "7. IAM (Identity and Access Management)"
    echo "8. AWS Shield"
    
    read -p "Enter your choice [1]: " choice
    
    case $choice in
        1)
            instance_ids=$(aws ec2 describe-instances \
                --query 'Reservations[*].Instances[*].[InstanceId]' \
                --output text
            )
            check_ec2_instances_parallel "$instance_ids"
            ;;
        2)
            read -p "Enter the RDS Instance Identifier: " db_instance_identifier
            check_rds_status "$db_instance_identifier"
            ;;
        3)
            read -p "Enter the S3 Bucket Name: " bucket_name
            check_s3_storage_usage "$bucket_name"
            ;;
        4)
            read -p "Enter the Elastic Beanstalk Application Name: " app_name
            read -p "Enter the Elastic Beanstalk Environment Name: " env_name
            check_beanstalk_status "$app_name" "$env_name"
            ;;
        5)
            read -p "Enter the CloudFront Distribution ID: " distribution_id
            check_cloudfront_status "$distribution_id"
            ;;
        6)
            read -p "Enter the VPC ID: " vpc_id
            check_vpc_status $vpc_id
            ;;
        7)
            read -p "Enter the entity type (user/role): " entity_type
            check_iam_entities_status $entity_type
            ;;
        8)
            read -p "Enter the protection ID: " protection_id
            check_shield_protection_status $protection_id
            ;;
        *) echo "Invalid choice!" ;;
    esac
}

# Main execution
rotate_logs
main
