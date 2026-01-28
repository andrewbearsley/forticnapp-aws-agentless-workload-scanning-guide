# Deployment Guide for FortiCNAPP AWS Agentless Workload Scanning

## Overview

This deployment guide provides step-by-step instructions for deploying FortiCNAPP AWS Agentless Workload Scanning. Agentless workload scanning enables vulnerability scanning for AWS EC2 instances without installing agents on target systems.

This guide covers prerequisites, deployment steps, architecture details, and configuration options for AWS environments.

## Quick Start

### Step 1: Install Prerequisites

Install and configure the required tools:

1. **Lacework CLI**: [Install and Configure Lacework CLI](INSTALL-LACEWORK-CLI.md)
2. **Terraform**: [Install Terraform](INSTALL-TERRAFORM.md)
3. **AWS CLI**: [Install and Configure AWS CLI](INSTALL-AWS-CLI.md)

### Step 2: Gather Information

Gather the following information before generating Terraform configuration:

- **Deployment type**: `single-account` or `organization`
  - Example: `organization`
- **AWS Account ID (scanning account)**: The account where agentless scanning infrastructure will be deployed
  - Example: `123456789012`
- **AWS Regions**: Comma-separated list of regions where EC2 instances will be scanned
  - Example: `ap-southeast-2,us-east-1`
- **Organization ID** (for organization deployments): Your AWS Organization ID
  - Example: `o-abc123def4`

### Step 3: Generate Terraform Configuration

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

### Step 4: Authenticate with AWS CLI

```bash
# Using IAM credentials
aws configure

# Or using SSO
aws sso login --profile <profile-name>
export AWS_PROFILE=<profile-name>
```

### Step 5: Deploy with Terraform

Navigate to the generated Terraform directory and deploy:

```bash
cd ~/lacework/aws
terraform init
terraform plan
terraform apply
```

### Step 6: Verify Integration Status

In the Lacework FortiCNAPP console, navigate to **Settings > Integrations > Cloud accounts**. The status of the integration displays as **Success** if all resources are installed correctly.

Reference:
- [lacework generate cloud-account aws](https://docs.fortinet.com/document/forticnapp/latest/cli-reference/635459/lacework-generate-cloud-account-aws)
- [Single account deployment](https://docs.fortinet.com/document/forticnapp/latest/administration-guide/983212/integrating-agentless-workload-scanning-for-aws-single-account-with-terraform)
- [Organization deployment](https://docs.fortinet.com/document/forticnapp/latest/administration-guide/864699/integrating-agentless-workload-scanning-for-aws-organization-account-with-terraform)

## How It Works

### AWS Process
1. CloudWatch Event Rules trigger ECS tasks on a scheduled basis
2. ECS tasks create snapshots of EC2 instances with attached EBS volumes
3. Snapshots are analyzed for vulnerabilities within the AWS organization
4. Snapshots are deleted after scanning
5. Scan results (metadata) are stored in S3
6. Lacework retrieves scan results via cross-account IAM role
7. ECS tasks require outbound internet connectivity to Lacework APIs for configuration updates, diagnostic reporting, and on-demand scan requests

## Deployment Details

### Architecture
- ECS Fargate Cluster including Capacity Providers and Task Definitions
- CloudWatch Event Rules for scheduled scanning
- VPC, Subnets, Security Groups (can use existing or create new)
- IAM Roles and Policies for ECS tasks and cross-account access
- S3 Bucket for storing scan results/metadata
- CloudWatch Log Groups for ECS task logs

### Terraform Module
- Terraform module: https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest

### Documentation
- Single account: https://docs.fortinet.com/document/forticnapp/latest/administration-guide/983212/integrating-agentless-workload-scanning-for-aws-single-account-with-terraform
- Organization: https://docs.fortinet.com/document/forticnapp/latest/administration-guide/864699/integrating-agentless-workload-scanning-for-aws-organization-account-with-terraform
- FAQs: https://docs.fortinet.com/document/forticnapp/latest/administration-guide/269317/agentless-workload-scanning-faqs

### Terraform Deployment

#### Resources Provisioned

**Global Resources (deployed once per integration):**
- ECS Cluster (`aws_ecs_cluster.agentless_scan_ecs_cluster`)
- ECS Cluster Capacity Providers (`aws_ecs_cluster_capacity_providers.agentless_scan_capacity_providers`) - configured for Fargate
- ECS Task Definition (`aws_ecs_task_definition.agentless_scan_task_definition`)
- S3 Bucket for storing scan results/metadata
- AWS Secrets Manager Secret - stores Lacework account and token credentials
- CloudWatch Log Groups (`aws_cloudwatch_log_group.agentless_scan_log_group`) - for ECS task logs

**Regional Resources (deployed per region):**
- CloudWatch Event Rules (`aws_cloudwatch_event_rule.agentless_scan_event_rule`) - for scheduled scanning
- CloudWatch Event Target (`aws_cloudwatch_event_target.agentless_scan_event_target`)
- VPC, Subnets, Security Groups (can use existing or create new)
- Internet Gateway (for outbound connectivity)
- VPC Flow Logs (optional)

**IAM Resources:**
- Event Role - allows EventBridge to trigger ECS tasks
- Task Execution Role - grants permissions for ECS tasks to pull container images and publish logs
- Task Role - provides scanning tasks with permissions for snapshot creation, S3 access, and ECS task management

#### Deployment Scenarios

**Single Account Deployment:**
- All infrastructure (VPC, ECS, internet egress) is deployed in the same account where workloads are scanned

**Organization Deployment:**
- **Scanning Account**: Requires VPC with internet egress, ECS Fargate cluster, CloudWatch Event Rules, S3 bucket, and all scanning infrastructure
- **Target/Monitored Accounts**: Only require IAM snapshot role (`snapshot_role = true`)
- **Management Account**: Only requires IAM snapshot role (`snapshot_role = true`)

See the [multi-account-multi-region example](https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest/examples/multi-account-multi-region) for a complete example.

#### Optional Inputs

**Using Existing Networking Resources:**

The Terraform module supports using existing VPC, subnets, and security groups instead of creating new ones:

- `use_existing_vpc = true` and provide `vpc_id` - The existing VPC must have an Internet Gateway attached (or set `use_internet_gateway = false` if routing through Transit Gateway/NAT Gateway)
- `use_existing_subnet = true` and provide `subnet_id` - Only a single subnet is needed
- `use_existing_security_group = true` and provide `security_group_id`

See the [single-account-existing-vpc-networking example](https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest/examples/single-account-existing-vpc-networking) for a complete example.

### IAM Permissions

#### Permissions Required for Deployment

The Terraform module requires IAM permissions to deploy the scanning infrastructure. The deploying user/role needs permissions to create:

- ECS resources (clusters, task definitions, capacity providers)
- VPC, subnets, security groups, internet gateways
- S3 buckets
- IAM roles and policies
- CloudWatch Event Rules and Log Groups
- Secrets Manager secrets

Reference: https://docs.fortinet.com/document/forticnapp/latest/administration-guide/538280/configuring-iam-permissions-for-deployment

#### Permissions Used During Workload Scanning

The scanning process uses cross-account IAM roles with the following permissions:

**Cross-Account Role (Lacework assumes this role):**
- Trust relationship with Lacework AWS account (`434813966438`) using external ID for security
- Role name: `lacework-agentless-scanning-cross-account-role-<UNIQUE_ID>`

**ECSTaskManagement Policy:**
- `ecs:RunTask` - Run ECS tasks within the scanning cluster
- `ecs:StopTask` - Stop ECS tasks
- `iam:PassRole` - Pass IAM roles required for task execution
- `ec2:DescribeSubnets` - Describe subnets for task placement (with specific tag conditions)

**S3WriteAllowPolicy:**
- `s3:PutBucketTagging`, `s3:ListBucket`, `s3:GetBucketTagging`, `s3:GetBucketLocation` - Manage S3 bucket
- `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject` - Manage objects in the S3 bucket

**Task Role (used by ECS tasks during scanning):**
- EC2 permissions for snapshot creation and management:
  - `ec2:CreateSnapshot` - Create snapshots of EBS volumes
  - `ec2:DescribeInstances`, `ec2:DescribeVolumes`, `ec2:DescribeSnapshots` - Describe EC2 resources
  - `ec2:DeleteSnapshot` - Delete snapshots after scanning
- Cross-account role assumption (for organization-wide scanning)
- S3 permissions to store scan results

Reference: https://docs.fortinet.com/document/forticnapp/latest/administration-guide/294031/iam-permissions-used-during-workload-scanning

## Resources

- [FortiCNAPP Documentation](https://docs.fortinet.com/document/forticnapp/latest/administration-guide/966589/agentless-workload-scanning)
- [Terraform Registry - AWS Module](https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest)
- [Agentless Workload Scanning FAQs](https://docs.fortinet.com/document/forticnapp/latest/administration-guide/269317/agentless-workload-scanning-faqs)
