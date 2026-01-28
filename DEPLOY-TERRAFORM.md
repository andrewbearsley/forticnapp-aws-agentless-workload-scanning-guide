# Deploying with Terraform

This guide covers deploying FortiCNAPP AWS Agentless Workload Scanning using Terraform.

## Prerequisites

Install and configure the required tools:

1. **Lacework CLI**: [Install and Configure Lacework CLI](INSTALL-LACEWORK-CLI.md)
2. **Terraform**: [Install Terraform](INSTALL-TERRAFORM.md)
3. **AWS CLI**: [Install and Configure AWS CLI](INSTALL-AWS-CLI.md)

## Quick Start

### Step 1: Gather Information

Gather the following information before generating Terraform configuration:

- **Deployment type**: `single-account` or `organization`
- **AWS Account ID (scanning account)**: The account where agentless scanning infrastructure will be deployed
- **AWS Regions**: Comma-separated list of regions where EC2 instances will be scanned
- **Organization ID** (for organization deployments): Your AWS Organization ID

### Step 2: Generate Terraform Configuration

Generate Terraform configuration using the Lacework CLI:

**Single Account:**
```bash
lacework generate cloud-account aws \
  --agentless \
  --aws_account_id <account-id> \
  --aws_region <region>
```

**Organization:**
```bash
lacework generate cloud-account aws \
  --agentless \
  --organization \
  --organization_id <org-id> \
  --aws_account_id <scanning-account-id> \
  --aws_region <region>
```

Terraform files are created in `~/lacework/aws` by default.

### Step 3: Authenticate with AWS CLI

```bash
# Using IAM credentials
aws configure

# Or using SSO
aws sso login --profile <profile-name>
export AWS_PROFILE=<profile-name>
```

### Step 4: Deploy with Terraform

```bash
cd ~/lacework/aws
terraform init
terraform plan
terraform apply
```

### Step 5: Verify Integration Status

In the Lacework FortiCNAPP console, navigate to **Settings > Integrations > Cloud accounts**. The status displays as **Success** if all resources are installed correctly.

## Deployment Scenarios

**Single Account Deployment:**
- All infrastructure (VPC, ECS, internet egress) is deployed in the same account where workloads are scanned

**Organization Deployment:**
- **Scanning Account**: Requires VPC with internet egress, ECS Fargate cluster, CloudWatch Event Rules, S3 bucket, and all scanning infrastructure
- **Target/Monitored Accounts**: Only require IAM snapshot role (`snapshot_role = true`)
- **Management Account**: Only requires IAM snapshot role (`snapshot_role = true`)

See the [multi-account-multi-region example](https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest/examples/multi-account-multi-region) for a complete example.

## Using Existing VPC

The Terraform module supports using existing VPC, subnets, and security groups instead of creating new ones.

### Requirements

| Resource | Requirement |
|----------|-------------|
| **VPC** | Must have internet connectivity (Internet Gateway, NAT Gateway, or Transit Gateway route) |
| **Subnet** | Must have a route to the internet for outbound HTTPS traffic |
| **Security Group** | Must allow outbound HTTPS (port 443/tcp) to 0.0.0.0/0. No inbound rules required. |

### Discovering Existing Resources

Use the included resource lookup script to interactively discover and validate your existing AWS resources:

```bash
# Set AWS environment variables
export AWS_ACCOUNT_ID=<account-id>
export AWS_REGION=<region>
export AWS_PROFILE=<profile>

# Run the resource lookup script
./scripts/aws-resource-lookup.sh
```

The script will:
1. List all VPCs in your region
2. List subnets for your selected VPC
3. List security groups and validate HTTPS egress rules
4. Display a summary of selected resources for your Terraform configuration

Alternatively, use the AWS CLI directly:

```bash
# List VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock]' --output table

# List subnets for a VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' --output table

# List security groups for a VPC
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' --output table
```

### Module Configuration

```hcl
module "lacework_aws_agentless_scanning" {
  source  = "lacework/agentless-scanning/aws"
  version = "~> 0.10"

  global   = true
  regional = true

  # Existing VPC configuration
  use_existing_vpc        = true
  use_internet_gateway    = false  # Set false if VPC already has IGW
  vpc_id                  = "vpc-xxxxxxxxx"

  # Existing subnet configuration
  use_existing_subnet     = true
  subnet_id               = "subnet-xxxxxxxxx"

  # Existing security group configuration
  use_existing_security_group = true
  security_group_id           = "sg-xxxxxxxxx"
}
```

**Note:** When using an existing VPC with `use_internet_gateway = false`, the module assumes internet connectivity already exists via your existing network architecture.

See the [single-account-existing-vpc-networking example](https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest/examples/single-account-existing-vpc-networking) for a complete example.

## Resources Provisioned

**Global Resources (deployed once per integration):**
- ECS Cluster with Fargate Capacity Providers
- ECS Task Definition
- S3 Bucket for scan results/metadata
- AWS Secrets Manager Secret (Lacework credentials)
- CloudWatch Log Groups

**Regional Resources (deployed per region):**
- CloudWatch Event Rules for scheduled scanning
- CloudWatch Event Target
- VPC, Subnets, Security Groups (unless using existing)
- Internet Gateway (for outbound connectivity)

**IAM Resources:**
- Event Role - allows EventBridge to trigger ECS tasks
- Task Execution Role - ECS tasks to pull images and publish logs
- Task Role - snapshot creation, S3 access, ECS task management

## IAM Permissions

### Permissions Required for Deployment

The deploying user/role needs permissions to create:
- ECS resources (clusters, task definitions, capacity providers)
- VPC, subnets, security groups, internet gateways
- S3 buckets
- IAM roles and policies
- CloudWatch Event Rules and Log Groups
- Secrets Manager secrets

Reference: [Configuring IAM Permissions for Deployment](https://docs.fortinet.com/document/forticnapp/latest/administration-guide/538280/configuring-iam-permissions-for-deployment)

### Permissions Used During Workload Scanning

**Cross-Account Role (Lacework assumes this role):**
- Trust relationship with Lacework AWS account (`434813966438`) using external ID

**ECSTaskManagement Policy:**
- `ecs:RunTask`, `ecs:StopTask` - Manage ECS tasks
- `iam:PassRole` - Pass IAM roles for task execution
- `ec2:DescribeSubnets` - Describe subnets for task placement

**S3WriteAllowPolicy:**
- `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject` - Manage scan results
- `s3:PutBucketTagging`, `s3:ListBucket`, `s3:GetBucketTagging`, `s3:GetBucketLocation`

**Task Role (used by ECS tasks):**
- `ec2:CreateSnapshot`, `ec2:DeleteSnapshot` - Snapshot management
- `ec2:DescribeInstances`, `ec2:DescribeVolumes`, `ec2:DescribeSnapshots`
- Cross-account role assumption (for organization scanning)
- S3 permissions to store scan results

Reference: [IAM Permissions Used During Workload Scanning](https://docs.fortinet.com/document/forticnapp/latest/administration-guide/294031/iam-permissions-used-during-workload-scanning)

## References

- [Terraform Module](https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest)
- [Single Account Deployment Guide](https://docs.fortinet.com/document/forticnapp/latest/administration-guide/983212/integrating-agentless-workload-scanning-for-aws-single-account-with-terraform)
- [Organization Deployment Guide](https://docs.fortinet.com/document/forticnapp/latest/administration-guide/864699/integrating-agentless-workload-scanning-for-aws-organization-account-with-terraform)
- [lacework generate cloud-account aws](https://docs.fortinet.com/document/forticnapp/latest/cli-reference/635459/lacework-generate-cloud-account-aws)
