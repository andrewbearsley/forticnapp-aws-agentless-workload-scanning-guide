# Deploying with CloudFormation

This guide covers deploying FortiCNAPP AWS Agentless Workload Scanning using CloudFormation.

## Prerequisites

You need:
- Access to FortiCNAPP UI
- Permissions for: CloudFormation, IAM, ECS, VPC, S3, CloudWatch, Organizations (read)

## Quick Start

### Step 1: Deploy Scanning Account Infrastructure

Deploy from FortiCNAPP UI in your **scanning account** (where scanning infrastructure will run):

1. Log into FortiCNAPP UI (`https://<your-account>.lacework.net`)
2. Navigate to: **Settings > Cloud Accounts**
3. Click **Add Cloud Account** and select **AWS Agentless Scanning**
4. In Step 1 "Set up AWS Scanning Account", click **Launch Stack**
5. AWS CloudFormation console opens with template pre-filled
6. Fill in parameters:
   - **Regions**: Comma-separated list, e.g., `ap-southeast-1,ap-southeast-2`
   - **VPCQuotaCheck**: `Yes`
   - **ResourceNamePrefix**: e.g., `lacework-agentless`
   - **ResourceNameSuffix**: e.g., `acme`
7. Click **Create stack** and wait for completion
8. Save the stack outputs: `CrossAccountRoleArn`, `ECSTaskRoleArn`, `S3BucketArn`, `ExternalId`

### Step 2: Deploy Snapshot Roles (Optional - Organization Only)

**Skip this step if scanning a single account.**

For AWS Organizations, deploy from your **management account** using StackSets to create snapshot roles in monitored accounts:

1. Return to FortiCNAPP UI setup wizard
2. In Step 2 "Integrate AWS Scanning Account with your AWS Organization", click **Launch Stack**
3. Fill in parameters using outputs from Step 1:
   - **CrossAccountRoleArn**: `<from Step 1>`
   - **ECSTaskRoleArn**: `<from Step 1>`
   - **S3BucketArn**: `<from Step 1>`
   - **ExternalId**: `<from Step 1>`
   - **MonitoredAccountDeployment**: `SERVICE_MANAGED`
   - **MonitoredAccountIds**: `r-xxxxx` (your Organization root ID or OU IDs)
4. Click **Create stack** and wait for completion

### Step 3: Verify Integration Status

In the Lacework FortiCNAPP console, navigate to **Settings > Integrations > Cloud accounts**. The status displays as **Success** if all resources are installed correctly.

## Template Source

CloudFormation templates are generated from the FortiCNAPP UI with account-specific parameters (LaceworkServerToken, ExternalId). Templates should be downloaded/launched from the UI rather than stored separately.

**Important:** The ExternalId is hardcoded in the template and cannot be changed after generation. It's required for IAM trust relationships with FortiCNAPP.

## Using Existing VPC (Optional)

CloudFormation creates a new VPC by default (one per selected region). To use an existing VPC, update the ECS service after deployment.

**Note:** Repeat this process for each region where you want to use an existing VPC.

**Prerequisites:** [AWS CLI](INSTALL-AWS-CLI.md)

### Requirements

| Resource | Requirement |
|----------|-------------|
| **Subnet** | Must be in the same region as ECS service |
| **Security Group** | Must allow outbound HTTPS (port 443/tcp) |
| **Private Subnets** | Must have NAT gateway or VPC endpoints |

### Step 1: Find ECS Resources

```bash
# Set the region
REGION="ap-southeast-2"

# Find the ECS cluster
CLUSTER=$(aws ecs list-clusters --region $REGION \
  --query 'clusterArns[?contains(@, `lacework`)]' \
  --output text | awk -F'/' '{print $NF}')

# Find the service
SERVICE=$(aws ecs list-services --region $REGION \
  --cluster $CLUSTER \
  --query 'serviceArns[0]' \
  --output text | awk -F'/' '{print $NF}')

echo "Cluster: $CLUSTER"
echo "Service: $SERVICE"
```

### Step 2: Update ECS Service

```bash
# Replace with your actual subnet and security group IDs
EXISTING_SUBNET="subnet-xxxxxxxxx"
EXISTING_SECURITY_GROUP="sg-xxxxxxxxx"

# Update service network configuration
aws ecs update-service --region $REGION \
  --cluster $CLUSTER \
  --service $SERVICE \
  --network-configuration "awsvpcConfiguration={
    subnets=[$EXISTING_SUBNET],
    securityGroups=[$EXISTING_SECURITY_GROUP],
    assignPublicIp=DISABLED
  }" \
  --force-new-deployment

# Wait for service to stabilize
aws ecs wait services-stable --region $REGION --cluster $CLUSTER --services $SERVICE
```

### Step 3: Verify the Update

```bash
# Check service status
aws ecs describe-services --region $REGION \
  --cluster $CLUSTER \
  --services $SERVICE \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# Verify tasks are in correct subnet
TASK_ARN=$(aws ecs list-tasks --region $REGION \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --query 'taskArns[0]' \
  --output text)

aws ecs describe-tasks --region $REGION \
  --cluster $CLUSTER \
  --tasks $TASK_ARN \
  --query 'tasks[0].attachments[0].details[?name==`subnetId`].value' \
  --output text
```

### What Happens

- ECS service network configuration is updated
- New tasks are launched in the specified subnet with the specified security group
- Old tasks are drained and stopped
- Service continues running with new network configuration
- The original VPC created by CloudFormation remains but is unused

## Resources Provisioned

**Scanning Account Stack (per selected region):**
- VPC with network infrastructure (one per region)
- ECS cluster and service (one per region)
- S3 bucket for scan results
- IAM roles (cross-account role, task role, task execution role)
- CloudWatch log groups

**Snapshot Roles Stack (Optional - Organization Only):**
- IAM snapshot roles in all monitored accounts
- Deployed from management account via StackSets across AWS Organization

## IAM Permissions

### Permissions Required for Deployment

The deploying user/role needs permissions to create:
- CloudFormation stacks and StackSets
- ECS resources (clusters, services, task definitions)
- VPC, subnets, security groups, internet gateways
- S3 buckets
- IAM roles and policies
- CloudWatch Log Groups

### Permissions Used During Workload Scanning

**Cross-Account Role (Lacework assumes this role):**
- Trust relationship with Lacework AWS account (`434813966438`) using external ID

**Task Role (used by ECS tasks):**
- `ec2:CreateSnapshot`, `ec2:DeleteSnapshot` - Snapshot management
- `ec2:DescribeInstances`, `ec2:DescribeVolumes`, `ec2:DescribeSnapshots`
- Cross-account role assumption (for organization scanning)
- S3 permissions to store scan results

Reference: <a href="https://docs.fortinet.com/document/forticnapp/latest/administration-guide/294031/iam-permissions-used-during-workload-scanning" target="_blank">IAM Permissions Used During Workload Scanning</a>

## References

- <a href="https://docs.fortinet.com/document/forticnapp/latest/administration-guide/966589/agentless-workload-scanning" target="_blank">Deploying Agentless Workload Scanning on AWS</a>
- <a href="https://docs.fortinet.com/document/forticnapp/latest/administration-guide/269317/agentless-workload-scanning-faqs" target="_blank">Agentless Workload Scanning FAQs</a>
