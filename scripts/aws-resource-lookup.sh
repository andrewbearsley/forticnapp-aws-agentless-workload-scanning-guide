#!/bin/bash

# AWS Resource Lookup Script for Lacework Agentless Scanning
# This script helps identify AWS resources needed for Lacework Agentless Workload Scanning deployment

# Exit on error
set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display section headers
section() {
  echo -e "\n${BOLD}${BLUE}$1${NC}\n"
}

# Function to display prompts
prompt() {
  echo -e "${BOLD}${YELLOW}$1${NC}"
}

# Function to display success messages
success() {
  echo -e "${GREEN}$1${NC}"
}

# Check if required tools are installed
if ! command -v aws &> /dev/null; then
  echo "Error: AWS CLI is not installed. Please install it first."
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Please install it first with 'brew install jq'."
  exit 1
fi

# Setup AWS environment variables
setup_aws_env() {
  section "AWS CLI Setup"
  
  # Prompt for AWS Account ID if not set
  if [ -z "$AWS_ACCOUNT_ID" ]; then
    prompt "Enter your AWS Account ID:"
    read AWS_ACCOUNT_ID
    export AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
  fi
  
  # Prompt for AWS Region if not set
  if [ -z "$AWS_REGION" ]; then
    prompt "Enter your AWS Region (e.g., ap-southeast-2):"
    read AWS_REGION
    export AWS_REGION=$AWS_REGION
  fi
  
  # Prompt for AWS Profile if not set
  if [ -z "$AWS_PROFILE" ]; then
    prompt "Enter your AWS Profile:"
    read AWS_PROFILE
    export AWS_PROFILE=$AWS_PROFILE
  fi
  
  # Disable AWS pager
  export AWS_PAGER=""
  
  echo "AWS Environment Variables:"
  echo "AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID"
  echo "AWS_REGION=$AWS_REGION"
  echo "AWS_PROFILE=$AWS_PROFILE"
  echo "AWS_PAGER=$AWS_PAGER"
  
  success "AWS CLI setup complete!"
}

# List VPCs in the region
list_vpcs() {
  section "1. Listing VPCs in $AWS_REGION"
  
  # Get VPCs and save to variable
  VPC_LIST=$(aws ec2 describe-vpcs --query "Vpcs[*].[VpcId,Tags[?Key=='Name'].Value|[0],CidrBlock]" --output json)
  
  # Display VPCs in table format
  aws ec2 describe-vpcs --query "Vpcs[*].[VpcId,Tags[?Key=='Name'].Value|[0],CidrBlock]" --output table
  
  # Count number of VPCs
  VPC_COUNT=$(echo $VPC_LIST | jq '. | length')
  
  # If only one VPC exists, select it automatically
  if [ "$VPC_COUNT" -eq 1 ]; then
    VPC_ID=$(echo $VPC_LIST | jq -r '.[0][0]')
    echo "Only one VPC found. Automatically selecting: $VPC_ID"
  else
    prompt "Enter the VPC ID you want to use (vpc-xxxxxxxx):"
    read VPC_ID
  fi
  
  export VPC_ID=$VPC_ID
  success "VPC ID set to: $VPC_ID"
}

# Find subnets for the selected VPC
find_subnets() {
  section "2. Finding subnets for VPC: $VPC_ID"
  aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]" --output table
  
  prompt "Enter the Subnet ID you want to use (subnet-xxxxxxxx):"
  read SUBNET_ID
  export SUBNET_ID=$SUBNET_ID
  
  success "Subnet ID set to: $SUBNET_ID"
}

# Find security groups for the selected VPC
find_security_groups() {
  section "3. Finding security groups for VPC: $VPC_ID"
  
  # Get security groups and save to variable
  SG_LIST=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --output json)
  
  # Display security groups in table format with egress information
  echo "Security Groups for VPC: $VPC_ID"
  echo "-------------------------------------------------------------------------"
  echo "| Security Group ID       | Name                 | Has HTTPS Egress    |"
  echo "-------------------------------------------------------------------------"
  
  # Process each security group
  SG_IDS=($(echo $SG_LIST | jq -r '.SecurityGroups[].GroupId'))
  
  for sg in ${SG_IDS[@]}; do
    # Get security group details
    SG_NAME=$(echo $SG_LIST | jq -r ".SecurityGroups[] | select(.GroupId == \"$sg\") | .GroupName")
    
    # Check for HTTPS egress rule
    SG_RULES=$(aws ec2 describe-security-group-rules --filter "Name=group-id,Values=$sg" --output json)
    
    # Check if there's an egress rule allowing HTTPS (port 443) or all traffic (-1)
    HAS_HTTPS_EGRESS=$(echo $SG_RULES | jq -r '.SecurityGroupRules[] | select(.IsEgress == true) | select((.IpProtocol == "-1") or (.IpProtocol == "tcp" and .FromPort <= 443 and .ToPort >= 443))' | wc -l)
    
    if [ $HAS_HTTPS_EGRESS -gt 0 ]; then
      EGRESS_STATUS="Yes"
    else
      EGRESS_STATUS="No"
    fi
    
    # Print security group information
    printf "| %-24s | %-21s | %-19s |\n" "$sg" "$SG_NAME" "$EGRESS_STATUS"
  done
  
  echo "-------------------------------------------------------------------------"
  echo "Note: 'Has HTTPS Egress' indicates if the security group allows outbound HTTPS (port 443) traffic"
  echo ""
  
  # Count number of security groups
  SG_COUNT=$(echo $SG_LIST | jq '.SecurityGroups | length')
  
  # If only one security group exists, select it automatically
  if [ "$SG_COUNT" -eq 1 ]; then
    SECURITY_GROUP_ID=$(echo $SG_LIST | jq -r '.SecurityGroups[0].GroupId')
    echo "Only one security group found. Automatically selecting: $SECURITY_GROUP_ID"
  else
    prompt "Enter the Security Group ID you want to use (sg-xxxxxxxx):"
    read SECURITY_GROUP_ID
  fi
  
  export SECURITY_GROUP_ID=$SECURITY_GROUP_ID
  success "Security Group ID set to: $SECURITY_GROUP_ID"
}

# Verify security group allows outbound HTTPS traffic
verify_security_group() {
  section "4. Verifying security group allows outbound HTTPS traffic"
  
  # Get security group rules
  SG_RULES=$(aws ec2 describe-security-group-rules --filter "Name=group-id,Values=$SECURITY_GROUP_ID" --output json)
  
  # Display the rules
  aws ec2 describe-security-group-rules --filter "Name=group-id,Values=$SECURITY_GROUP_ID"
  
  # Check if there's an egress rule allowing HTTPS (port 443) or all traffic (-1)
  HAS_HTTPS_EGRESS=$(echo $SG_RULES | jq -r '.SecurityGroupRules[] | select(.IsEgress == true) | select((.IpProtocol == "-1") or (.IpProtocol == "tcp" and .FromPort <= 443 and .ToPort >= 443))' | wc -l)
  
  if [ $HAS_HTTPS_EGRESS -gt 0 ]; then
    echo ""
    success "✓ Security group has the required outbound HTTPS access."
    echo ""
  else
    echo ""
    echo "⚠️ Warning: The security group does not appear to have an outbound rule allowing HTTPS traffic."
    echo "Please verify the security group rules and ensure it allows outbound HTTPS (port 443) traffic."
    
    prompt "Do you want to continue anyway? (y/n):"
    read CONFIRM
    if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
      echo "Please update your security group to allow outbound HTTPS traffic and try again."
      exit 1
    fi
  fi
  
  success "Security group verification complete!"
}

# Display summary of selected resources
display_summary() {
  section "Resource Summary"
  echo "VPC ID: $VPC_ID"
  echo "Subnet ID: $SUBNET_ID"
  echo "Security Group ID: $SECURITY_GROUP_ID"
  echo "AWS Region: $AWS_REGION"
  
  echo ""
  echo "You can now use these values in your Terraform configuration."
  echo "Update the terraform/terraform.tfvars file with these values."
  
  # Check if terraform.tfvars exists and contains a different region
  TFVARS_PATH="../terraform/terraform.tfvars"
  if [ -f "$TFVARS_PATH" ]; then
    CURRENT_REGION=$(grep -o 'aws_region[[:space:]]*=[[:space:]]*"[^"]*"' "$TFVARS_PATH" | cut -d'"' -f2)
    
    if [ ! -z "$CURRENT_REGION" ] && [ "$CURRENT_REGION" != "$AWS_REGION" ]; then
      echo -e "\n${YELLOW}⚠️  Warning: The region in terraform/terraform.tfvars ($CURRENT_REGION) does not match your AWS_REGION ($AWS_REGION)${NC}"
      echo "You should update the region in terraform/terraform.tfvars to match your AWS_REGION."
    fi
  fi
  
  success "Resource lookup complete!"
}

# Check if required AWS environment variables are set
check_aws_env() {
  local missing_vars=false
  
  if [ -z "$AWS_ACCOUNT_ID" ]; then
    missing_vars=true
  fi
  
  if [ -z "$AWS_REGION" ]; then
    missing_vars=true
  fi
  
  if [ -z "$AWS_PROFILE" ]; then
    missing_vars=true
  fi
  
  # If any required variables are missing, show helper text
  if [ "$missing_vars" = true ]; then
    echo -e "${YELLOW}Required AWS environment variables are not set.${NC}"
    echo -e "Please set the following environment variables before running this script:\n"
    echo -e "${BOLD}export AWS_ACCOUNT_ID=[Your AWS Account ID] && \\
    export AWS_REGION=[Your AWS Region] && \\
    export AWS_PROFILE=[Your AWS Profile] && \\
    export AWS_PAGER=""${NC}\n"
    echo -e "Example:\n"
    echo -e "${BOLD}export AWS_ACCOUNT_ID=631604671854 && \\
    export AWS_REGION=ap-southeast-2 && \\
    export AWS_PROFILE=sandbox-admin && \\
    export AWS_PAGER=""${NC}\n"
    
    prompt "Do you want to set these variables now? (y/n):"
    read SET_VARS
    
    if [[ $SET_VARS == "y" || $SET_VARS == "Y" ]]; then
      setup_aws_env
    else
      echo "Exiting script. Please set the required environment variables and try again."
      exit 1
    fi
  else
    # If variables are already set, just display them
    echo "AWS Environment Variables:"
    echo "AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID"
    echo "AWS_REGION=$AWS_REGION"
    echo "AWS_PROFILE=$AWS_PROFILE"
    echo "AWS_PAGER=$AWS_PAGER"
  fi
}

# Main execution
main() {
  echo -e "${BOLD}Lacework Agentless Scanning - AWS Resource Lookup${NC}"
  echo "This script will help you identify the AWS resources needed for deployment."
  echo ""
  
  # Always set AWS_PAGER to empty string
  export AWS_PAGER=""
  
  # Check if required AWS environment variables are set
  check_aws_env
  
  list_vpcs
  find_subnets
  find_security_groups
  verify_security_group
  display_summary
  
  section "Next Steps"
  echo "1. Navigate to the terraform directory"
  echo "2. Update the terraform/terraform.tfvars file with these values:"
  echo -e "   ${BOLD}aws_region        = \"$AWS_REGION\"${NC}"
  echo -e "   ${BOLD}vpc_id            = \"$VPC_ID\"${NC}"
  echo -e "   ${BOLD}security_group_id = \"$SECURITY_GROUP_ID\"${NC}"
  echo -e "   ${BOLD}subnet_id         = \"$SUBNET_ID\"${NC}"
  echo "3. Run: terraform init"
  echo "4. Run: terraform plan"
  echo "5. Run: terraform apply"
}

# Run the script
main
