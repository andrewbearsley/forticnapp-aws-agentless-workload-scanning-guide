# FortiCNAPP AWS Agentless Workload Scanning

Deployment guide for FortiCNAPP Agentless Workload Scanning on AWS.

## Overview

FortiCNAPP Agentless Workload Scanning provides vulnerability scanning for AWS EC2 instances without requiring agents to be installed on target systems. Scanning is performed by creating snapshots of EBS volumes and analyzing them for vulnerabilities.

## Deployment Methods

| Method | Best For | Guide |
|--------|----------|-------|
| **Terraform** | Infrastructure-as-code, CI/CD pipelines, existing VPC | [Deploy with Terraform](DEPLOY-TERRAFORM.md) |
| **CloudFormation** | UI-guided deployment, simpler setup | [Deploy with CloudFormation](DEPLOY-CLOUDFORMATION.md) |

## How It Works

1. CloudWatch Event Rules trigger an ECS scanning task, per region, on a scheduled basis.
2. The ECS scanning task assumes a role in the target account and creates snapshots of EC2 instances with attached EBS volumes.
3. Snapshots are analyzed for package vulnerabilities and secrets.
4. Snapshots are deleted after scanning
5. Scan results (metadata) are stored in S3
6. Lacework FortiCNAPP retrieves scan results via cross-account IAM role

## Architecture

Infrastructure is deployed in a dedicated **scanning account**:

- **Compute**: ECS Fargate Cluster (one per region) with scheduled scanning tasks
- **Networking**: VPC with outbound internet connectivity (one per region) in the AWS scanning account (where the ECS cluster is deployed)
- **Storage**: S3 Bucket for scan results/metadata
- **IAM**: Cross-account roles for snapshot creation and Lacework FortiCNAPP S3 read access
- **Logging**: CloudWatch Log Groups for ECS task logs

## Prerequisites

**Terraform:**
- [AWS CLI](INSTALL-AWS-CLI.md)
- [Lacework CLI](INSTALL-LACEWORK-CLI.md)
- [Terraform](INSTALL-TERRAFORM.md)

**CloudFormation:**
- [AWS CLI](INSTALL-AWS-CLI.md) (optional)

## Resources

- <a href="https://docs.fortinet.com/document/forticnapp/latest/administration-guide/966589/agentless-workload-scanning" target="_blank">FortiCNAPP Documentation</a>
- <a href="https://registry.terraform.io/modules/lacework/agentless-scanning/aws/latest" target="_blank">Terraform Module</a>
- <a href="https://docs.fortinet.com/document/forticnapp/latest/administration-guide/269317/agentless-workload-scanning-faqs" target="_blank">Agentless Workload Scanning FAQs</a>

