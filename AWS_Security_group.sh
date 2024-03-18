
#!/bin/bash

# Check if a profile name is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <aws-cli-profile-name>"
    exit 1
fi

PROFILE="$1"

# Disable paging for AWS CLI output
export AWS_PAGER=""

# List all security groups and their names
echo "Listing all security groups using profile: $PROFILE..."
aws ec2 describe-security-groups --profile $PROFILE --query 'SecurityGroups[*].[GroupId,GroupName]' --output text | while read SECURITY_GROUP_ID SECURITY_GROUP_NAME; do
    echo "Analyzing security group: $SECURITY_GROUP_ID ($SECURITY_GROUP_NAME)"

    # Check for inbound rules allowing traffic on ports 22 or 3389
    echo "Checking inbound rules for ports 22 (SSH) and 3389 (RDP)..."
    aws ec2 describe-security-groups --profile $PROFILE --group-ids $SECURITY_GROUP_ID \
        --query "SecurityGroups[].IpPermissions[?to_string(FromPort)=='22' || to_string(FromPort)=='3389' && IpProtocol=='tcp']" \
        --output text

    # Check related EC2 Instances
    echo "Checking related EC2 instances..."
    aws ec2 describe-instances --profile $PROFILE --filters Name=instance.group-id,Values=$SECURITY_GROUP_ID --query "Reservations[*].Instances[*].[InstanceId,InstanceType]" --output text

    # Check related RDS Instances
    echo "Checking related RDS databases..."
    aws rds describe-db-instances --profile $PROFILE --query "DBInstances[?VpcSecurityGroups[?VpcSecurityGroupId=='$SECURITY_GROUP_ID']].[DBInstanceIdentifier,DBInstanceClass]" --output text

    # Check related Classic Load Balancers
    echo "Checking related Classic Load Balancers..."
    aws elb describe-load-balancers --profile $PROFILE --query "LoadBalancerDescriptions[?SecurityGroups[?contains(@, '$SECURITY_GROUP_ID')]].[LoadBalancerName,DNSName]" --output text

    # Check related Application/Network Load Balancers
    echo "Checking related Application/Network Load Balancers..."
    aws elbv2 describe-load-balancers --profile $PROFILE --query "LoadBalancers[?contains(SecurityGroups, '$SECURITY_GROUP_ID')].[LoadBalancerArn,LoadBalancerName]" --output text

    echo "------------------------------------------------------"
done

echo "Search completed."
