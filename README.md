# Lacework FortiCNAPP - AWS Agentless Workload Scanning Architecture and Deployment Details

## Overview

This repository contains architecture documentation and deployment details for Lacework FortiCNAPP Agentless Workload Scanning on AWS.

FortiCNAPP Agentless Workload Scanning provides vulnerability scanning for cloud workloads without requiring agents to be installed on target systems. This repository documents the architecture, deployment methods, and configuration details for AWS environments.

## How It Works

### AWS Process
1. CloudWatch Event Rules trigger ECS tasks on a scheduled basis
2. ECS tasks create snapshots of EC2 instances with attached EBS volumes
3. Snapshots are analyzed for vulnerabilities within the AWS organization
4. Snapshots are deleted after scanning
5. Scan results (metadata) are stored in S3
6. Lacework retrieves scan results via cross-account IAM role

## Deployment Methods

Both CloudFormation and Terraform are supported. Terraform is typically recommended since the terraform module is flexible to allow for existing networking resources (VPC, subnets, security groups) to be reused in the scanning account.

## Deployment Details

### Agentless Workload Scanning Process

- CloudWatch Event Rules trigger ECS tasks on a scheduled basis
- The ECS scanning task uses AWS APIs (ec2:CreateSnapshot) to create snapshots of EC2s with attached EBS volumes. These snapshots remain within the AWS organization. 
- Snapshots are analyzed for vulnerabilities then deleted after scanning.
- Scan results (metadata) are stored in S3.
- Lacework uses cross-account IAM role with read-only S3 access to retrieve scan results from the S3 bucket in the nominated AWS scanning account.
- ECS tasks require outbound internet connectivity to Lacework APIs for configuration updates, diagnostic reporting, and on-demand scan requests (can use Internet Gateway, NAT Gateway, or route through Transit Gateway). 

### FAQs

Docs - https://docs.fortinet.com/document/forticnapp/latest/administration-guide/269317/agentless-workload-scanning-faqs

### Architecture
- ECS Fargate Cluster including Capacity Providers and Task Definitions
- CloudWatch Event Rules for scheduled scanning
- VPC, Subnets, Security Groups (can use existing or create new)
- IAM Roles and Policies for ECS tasks and cross-account access
- S3 Bucket for storing scan results/metadata
- CloudWatch Log Groups for ECS task logs

### Account Requirements

**Single Account Deployment:**
- All infrastructure (VPC, ECS, internet egress) is deployed in the same account where workloads are scanned

**Organization Deployment:**

Based on the [Terraform module examples](https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest), organization deployments require different resources in different accounts:

- **Scanning Account (where infrastructure is deployed):**
  - Requires VPC with internet egress (Internet Gateway, NAT Gateway, or Transit Gateway route) - as documented: "ECS tasks require outbound internet connectivity to Lacework APIs"
  - Requires ECS Fargate cluster, CloudWatch Event Rules, S3 bucket, and all scanning infrastructure
  - ECS tasks run in this account and use AWS APIs (ec2:CreateSnapshot) to create snapshots in target accounts
  - Scan results are stored in S3 in the scanning account, and Lacework uses cross-account IAM role to retrieve them
  - Terraform module creates resources with `global = true` and `regional = true`

- **Target/Monitored Accounts (accounts being scanned):**
  - **Do NOT require** VPC, internet egress, or scanning infrastructure
  - Only require IAM snapshot role created with `snapshot_role = true` in the Terraform module
  - The snapshot role allows the scanning account to assume cross-account permissions to create snapshots
  - Snapshots are created, analyzed, and deleted within the target account's region via AWS APIs

- **Management Account (AWS Organizations management account):**
  - Only requires IAM snapshot role created with `snapshot_role = true` in the Terraform module
  - Used to enumerate accounts and OUs in the organization for scanning
  - **Do NOT require** VPC, internet egress, or scanning infrastructure

**Evidence:** See the [multi-account-multi-region example](https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest/examples/multi-account-multi-region) in the Terraform registry, which shows:
- `scanning_account.tf` creates global and regional resources (VPC, ECS, etc.)
- `monitored_account.tf` only creates `snapshot_role = true` (IAM role only)
- `management_account.tf` only creates `snapshot_role = true` (IAM role only)

### Terraform Module
- Terraform module: https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest

### Documentation
  - Single account: https://docs.fortinet.com/document/forticnapp/latest/administration-guide/983212/integrating-agentless-workload-scanning-for-aws-single-account-with-terraform
  - Organization: https://docs.fortinet.com/document/forticnapp/latest/administration-guide/864699/integrating-agentless-workload-scanning-for-aws-organization-account-with-terraform

### Deployment Details

The Terraform module provisions the following AWS resources:

**Compute & Orchestration:**
- ECS Cluster (`aws_ecs_cluster.agentless_scan_ecs_cluster`)
- ECS Cluster Capacity Providers (`aws_ecs_cluster_capacity_providers.agentless_scan_capacity_providers`) - configured for Fargate
- ECS Task Definition (`aws_ecs_task_definition.agentless_scan_task_definition`)

**Networking:**
- VPC (can use existing or create new)
- Subnets (can use existing or create new)
- Security Groups (can use existing or create new)
- Internet Gateway (for outbound connectivity)
- VPC Flow Logs (optional)

**Using Existing Networking Resources:**

The Terraform module supports using existing VPC, subnets, and security groups instead of creating new ones. This applies to both **single account** and **organization deployments**.

**For Organization Deployments:**
- VPC/networking configuration is **only needed in the scanning account**
- Monitored accounts and management accounts **do not require** VPC/networking configuration

To use existing resources in the scanning account's regional modules, set the following module inputs:
- `use_existing_vpc = true` and provide `vpc_id` - The existing VPC must have an Internet Gateway attached (or set `use_internet_gateway = false` if routing through Transit Gateway/NAT Gateway)
- `use_existing_subnet = true` and provide `subnet_id` - Only a single subnet is needed
- `use_existing_security_group = true` and provide `security_group_id`

**Note:** When using an existing VPC, the module will still create a new subnet using `vpc_cidr_block` unless `use_existing_subnet = true` is also set.

See the [single-account-existing-vpc-networking example](https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest/examples/single-account-existing-vpc-networking) for a complete example. The same VPC configuration options apply to the regional modules in organization deployments.

**Scheduling:**
- CloudWatch Event Rules (`aws_cloudwatch_event_rule.agentless_scan_event_rule`) - for scheduled scanning
- CloudWatch Event Target (`aws_cloudwatch_event_target.agentless_scan_event_target`)

**Storage:**
- S3 Bucket - for storing scan results/metadata

**IAM:**
- IAM Roles:
  - Event Role - allows EventBridge to trigger ECS tasks
  - Task Execution Role - grants permissions for ECS tasks to pull container images and publish logs
  - Task Role - provides scanning tasks with permissions for snapshot creation, S3 access, and ECS task management
- IAM Policies - associated with the above roles

**Logging & Monitoring:**
- CloudWatch Log Groups (`aws_cloudwatch_log_group.agentless_scan_log_group`) - for ECS task logs

**Secrets Management:**
- AWS Secrets Manager Secret - stores Lacework account and token credentials

Reference: https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest

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
