---
name: lacework-cli
description: Provides tools for investigating Lacework integrations, vulnerability assessments, agents, alerts, and compliance data using the Lacework CLI and API. Use when investigating Lacework data, extracting compliance reports, querying vulnerabilities, or working with Lacework endpoints.
---
# Lacework Investigation Tools

This skill provides tools for investigating Lacework integrations, vulnerability assessments, agents, alerts, and compliance data using the Lacework CLI and API.

## Tools

### check_cloud_integration

Check the status and configuration of cloud account integrations. Supports all integration types including AzureSidekick, AwsSidekickOrg, AzureCfg, AzureAlSeq, AwsCfg, and others.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials. JSON should have `account`, `keyId`, and `secret` fields.
- `integrationGuid` (string, optional): Integration GUID. If not provided, lists all integrations.
- `integrationType` (string, optional): Filter by integration type (e.g., "AzureSidekick", "AwsSidekickOrg", "AzureCfg")

**Returns:** Integration status, configuration, and state information.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework cloud-account list \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json

lacework cloud-account show <GUID> \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### list_agents

List all agents registered in the Lacework account. Shows both agent-based and agentless-scanned hosts.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `filter` (string, optional): Filter by hostname, OS, or other criteria

**Returns:** List of agents with hostname, OS, architecture, and status information.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework agent list \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### get_host_vulnerability_assessments

Get all vulnerability assessments for a specific host within a time range using the API search endpoint. Groups results by evalGuid to show unique assessments. Supports filtering by collector type, provider, severity, and CVE ID.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `machineId` (string): Machine ID (MID) to query
- `timeRange` (object): Time range for the query
  - `startTime` (string): Start time in ISO 8601 format (e.g., "2026-01-09T00:00:00Z")
  - `endTime` (string): End time in ISO 8601 format (e.g., "2026-01-16T00:00:00Z")
- `collectorType` (string, optional): Filter by collector type - "Agent", "Agentless", or "all" (default: "all")
- `provider` (string, optional): Filter by cloud provider - "Azure", "AWS", "GCP", etc.
- `severity` (string, optional): Filter by severity - "Critical", "High", "Medium", "Low", "Info"
- `cveId` (string, optional): Filter by specific CVE ID

**Returns:** Grouped assessments with evalGuid, collector type, timestamps, vulnerability counts, and details.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework api post /api/v2/Vulnerabilities/Hosts/search \
  -d '{
    "filters": [
      {"field": "mid", "expression": "eq", "value": "<MID>"},
      {"field": "evalCtx.collector_type", "expression": "eq", "value": "Agentless"}
    ],
    "timeFilter": {
      "startTime": "2026-01-09T00:00:00Z",
      "endTime": "2026-01-16T00:00:00Z"
    },
    "returns": ["mid", "evalCtx", "startTime", "endTime", "evalGuid", "vulnId", "severity"]
  }' \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### list_hosts_with_cve

List all hosts that have a specific CVE vulnerability.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `cveId` (string): CVE ID to search for (e.g., "CVE-2024-1234")

**Returns:** List of hosts with the specified CVE, including hostname, MID, and severity.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework vulnerability host list-hosts <CVE_ID> \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### show_host_assessment

Show the most recent vulnerability assessment for a specific host using the CLI command.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `machineId` (string): Machine ID (MID) to query

**Returns:** Most recent assessment data with vulnerability details.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework vulnerability host show-assessment <MID> \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### search_vulnerability_assessments

Search vulnerability assessments across multiple hosts using flexible filters. Groups results by machine ID and shows unique assessments per machine.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `timeRange` (object): Time range for the query
  - `startTime` (string): Start time in ISO 8601 format
  - `endTime` (string): End time in ISO 8601 format
- `collectorType` (string, optional): Filter by collector type - "Agent", "Agentless", or "all"
- `provider` (string, optional): Filter by cloud provider
- `severity` (string, optional): Filter by severity level
- `hostname` (string, optional): Filter by hostname pattern

**Returns:** List of machines with assessments matching the filters, including hostname, provider, and assessment counts.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework api post /api/v2/Vulnerabilities/Hosts/search \
  -d '{
    "filters": [
      {"field": "evalCtx.collector_type", "expression": "eq", "value": "Agentless"},
      {"field": "evalCtx.provider", "expression": "eq", "value": "Azure"}
    ],
    "timeFilter": {
      "startTime": "2026-01-09T00:00:00Z",
      "endTime": "2026-01-16T00:00:00Z"
    },
    "returns": ["mid", "evalCtx", "startTime", "endTime", "evalGuid"]
  }' \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### compare_assessment_types

Compare agent-based and agentless assessments for a specific machine. Shows assessments grouped by collector type.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `machineId` (string): Machine ID (MID) to query
- `timeRange` (object): Time range for the query
  - `startTime` (string): Start time in ISO 8601 format
  - `endTime` (string): End time in ISO 8601 format

**Returns:** Comparison of agent vs agentless assessments with counts and summary.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework api post /api/v2/Vulnerabilities/Hosts/search \
  -d '{
    "filters": [
      {"field": "mid", "expression": "eq", "value": "<MID>"}
    ],
    "timeFilter": {
      "startTime": "2026-01-09T00:00:00Z",
      "endTime": "2026-01-16T00:00:00Z"
    },
    "returns": ["mid", "evalCtx", "startTime", "endTime", "evalGuid", "vulnId", "severity"]
  }' \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### list_alerts

List alerts from Lacework. Supports filtering by severity, alert type, and time range.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `severity` (string, optional): Filter by severity - "Critical", "High", "Medium", "Low", "Info"
- `alertType` (string, optional): Filter by alert type
- `startTime` (string, optional): Start time for alert search
- `endTime` (string, optional): End time for alert search

**Returns:** List of alerts with details including severity, type, and description.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework alert list \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### show_alert

Show detailed information about a specific alert.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `alertGuid` (string): Alert GUID to retrieve

**Returns:** Detailed alert information including description, affected resources, and recommendations.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework alert show <GUID> \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### list_queries

List available Lacework Query Language (LQL) queries.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials

**Returns:** List of available queries with IDs and descriptions.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework query list \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### run_query

Run a Lacework Query Language (LQL) query.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `queryId` (string): Query ID to execute

**Returns:** Query results in JSON format.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework query run <query_id> \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### list_datasources

List available datasources for LQL queries.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials

**Returns:** List of available datasources.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework query list-sources \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### preview_datasource

Preview data from a specific datasource.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `datasource` (string): Datasource name to preview

**Returns:** Sample data from the datasource.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

lacework query preview-source <datasource> \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### make_api_call

Make a custom API call to any Lacework API endpoint. Supports GET, POST, PUT, DELETE, and PATCH methods.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `method` (string): HTTP method - "GET", "POST", "PUT", "DELETE", or "PATCH"
- `endpoint` (string): API endpoint path (e.g., "/api/v2/Vulnerabilities/Hosts/search" or "/api/v2/CloudAccounts")
- `data` (object, optional): Request body data for POST/PUT/PATCH requests (will be JSON-encoded)
- `queryParams` (object, optional): Query parameters as key-value pairs

**Returns:** API response in JSON format.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

# GET request
lacework api get /api/v2/CloudAccounts \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json

# POST request with data
lacework api post /api/v2/Vulnerabilities/Hosts/search \
  -d '{"filters": [], "timeFilter": {"startTime": "2026-01-09T00:00:00Z", "endTime": "2026-01-16T00:00:00Z"}}' \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

### get_compliance_report

Extract policy inventories and report data from compliance reports using the Reports API endpoint. This is the recommended approach for getting report data programmatically.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `reportName` (string): Exact report name (e.g., "CIS Amazon Web Services Foundations Benchmark v4.0.1")
- `reportType` (string, optional): Alternative to reportName (e.g., "AWS_CIS_14", "AZURE_CIS_1_5")
- `primaryQueryId` (string): 
  - AWS Account ID for AWS reports
  - Azure Tenant ID for Azure reports
- `secondaryQueryId` (string, optional): Azure Subscription ID (required for Azure reports)
- `format` (string, optional): Output format - "json", "pdf", "csv", or "html" (default: "pdf")

**Returns:** Report data including policy inventory with recommendations array containing:
- `REC_ID`: Policy ID (e.g., "lacework-global-31")
- `CATEGORY`: Section name (e.g., "Identity and Access Management")
- `TITLE`: Policy title
- `SEVERITY`: Numeric severity (1=Critical, 2=High, 3=Medium, 4=Low, 5=Info)

**Example - AWS Report:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

# Get AWS Account ID
AWS_ACCOUNT_ID=$(lacework api get "api/v2/CloudAccounts" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive | jq -r '.data[] | select(.type == "AwsCfg") | .data.awsAccountId' | head -1)

# Get report data
lacework api get "api/v2/Reports?format=json&primaryQueryId=${AWS_ACCOUNT_ID}&reportName=CIS Amazon Web Services Foundations Benchmark v4.0.1" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive
```

**Example - Azure Report:**
```bash
# Get Azure Tenant ID and Subscription ID
AZURE_TENANT_ID=$(lacework api get "api/v2/CloudAccounts" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive | jq -r '.data[] | select(.type == "AzureCfg") | .data.tenantId' | head -1)

AZURE_SUB_ID=$(lacework api get "api/v2/Configs/AzureSubscriptions" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive | jq -r '.data[0].subscriptions[0].subscriptionId' | head -1)

# Get Azure report data
lacework api get "api/v2/Reports?format=json&primaryQueryId=${AZURE_TENANT_ID}&secondaryQueryId=${AZURE_SUB_ID}&reportName=CIS Microsoft Azure Foundations Benchmark v4.0.0" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive
```

**Example - Using reportType:**
```bash
lacework api get "api/v2/Reports?format=json&primaryQueryId=${AWS_ACCOUNT_ID}&reportType=AWS_CIS_14" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive
```

**Response Structure:**
```json
{
  "data": [{
    "reportType": "CIS Amazon Web Services Foundations Benchmark v4.0.1",
    "reportTitle": "CIS Amazon Web Services Foundations Benchmark v4.0.1",
    "recommendations": [{
      "REC_ID": "lacework-global-31",
      "CATEGORY": "Identity and Access Management",
      "TITLE": "Maintain current contact details",
      "SEVERITY": 4
    }]
  }]
}
```

**Notes:**
- The `api/v2/ReportDefinitions` endpoint is broken and does not show recent definitions. Use `api/v2/Reports` instead.
- Reports must be available/executed in the account to retrieve data.
- For AWS reports, only `primaryQueryId` (AWS Account ID) is required.
- For Azure reports, both `primaryQueryId` (Tenant ID) and `secondaryQueryId` (Subscription ID) are required.
- The `format=json` parameter is essential for programmatic access.

### execute_custom_lql_query

Execute a custom Lacework Query Language (LQL) query with raw query text. Useful for ad-hoc queries or queries not saved in the account.

**Parameters:**
- `credentialsPath` (string): Path to JSON file containing credentials
- `queryText` (string): Raw LQL query text to execute
- `startTime` (string, optional): Start time for the query in ISO 8601 format
- `endTime` (string, optional): End time for the query in ISO 8601 format

**Returns:** Query results in JSON format.

**Example:**
```bash
CREDENTIALS_PATH="<credentials_path>"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")

# Execute custom LQL query via API
lacework api post /api/v2/Queries/execute \
  -d '{
    "queryText": "LW_HE_USERS_HISTORY",
    "arguments": {
      "StartTimeRange": "2026-01-09T00:00:00Z",
      "EndTimeRange": "2026-01-16T00:00:00Z"
    }
  }' \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json
```

## API Endpoint Discovery

Discovering and understanding API endpoints is critical for effective data extraction. The Lacework API provides structured access to compliance reports, inventory data, and other resources.

### Endpoint Discovery Best Practices

1. **Use Interactive API Documentation**
   - Access interactive docs at: https://api.lacework.net/api/v2/docs
   - Explore available endpoints, parameters, and response structures
   - Test endpoints directly in the browser interface

2. **Test Endpoints Systematically**
   - Start with base endpoints (e.g., `/api/v2/Reports`)
   - Test with different parameter combinations
   - Check both required and optional parameters
   - Verify response structures match expectations

3. **Understand Parameter Requirements**
   - Some endpoints require specific IDs (account ID, tenant ID, subscription ID)
   - Different cloud providers may need different parameters
   - Use `jq` to extract required IDs from related endpoints

4. **Check Response Structures**
   - Inspect actual API responses to understand data layout
   - Look for nested arrays and objects
   - Identify key fields needed for extraction

5. **Document Working Patterns**
   - Record successful endpoint calls and parameters
   - Note any limitations or special requirements
   - Document response structures for future reference

### Example: Discovering Report Endpoints

```bash
# 1. List available endpoints (if accessible)
lacework api get "api/v2/Reports" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive

# 2. Test with different parameters
lacework api get "api/v2/Reports?format=json" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive

# 3. Test with account ID
AWS_ACCOUNT_ID=$(lacework api get "api/v2/CloudAccounts" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive | jq -r '.data[0].data.awsAccountId')

lacework api get "api/v2/Reports?format=json&primaryQueryId=${AWS_ACCOUNT_ID}" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive

# 4. Test with report name
lacework api get "api/v2/Reports?format=json&primaryQueryId=${AWS_ACCOUNT_ID}&reportName=CIS Amazon Web Services Foundations Benchmark v4.0.1" \
  --account "$ACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET" \
  --json --noninteractive
```

### Key Learnings

- The `api/v2/Reports` endpoint is effective for getting report data, including policy inventories
- The `api/v2/ReportDefinitions` endpoint is broken and should not be used
- Different endpoints serve different purposes - test to find the right one
- Response structures vary - always inspect actual responses
- Parameter requirements differ by cloud provider (AWS vs Azure)

## Usage Notes

- All API queries use the Lacework CLI with JSON output format
- Time ranges are limited to 7 days maximum by the vulnerability API
- Results are automatically grouped by evalGuid to show unique assessments
- The API returns paginated results (up to 5,000 entries per page)
- Use `--noninteractive` flag to avoid pagers and spinners in scripts
- Credentials are provided via `credentialsPath` parameter pointing to a JSON file with `account`, `keyId`, and `secret` fields. Credentials will be extracted using `jq` or similar tools.
- Always use read-only commands (`list`, `show`, `query`, `get`) for investigations
- Avoid slow commands like `vulnerability host list-cves` unless necessary
- **Discover endpoints systematically** - test different parameter combinations to find working patterns
- **Inspect actual responses** - don't assume response structures match documentation

### Credentials JSON Format

When using `credentialsPath`, the JSON file should have this structure:
```json
{
  "account": "account-name",
  "keyId": "your-api-key-id",
  "secret": "your-api-secret"
}
```

To extract credentials from JSON:
```bash
CREDENTIALS_PATH="api-keys/creds.json"
ACCOUNT=$(jq -r '.account' "$CREDENTIALS_PATH")
API_KEY=$(jq -r '.keyId' "$CREDENTIALS_PATH")
API_SECRET=$(jq -r '.secret' "$CREDENTIALS_PATH")
```

## Common Workflows

### Check cloud integration status
1. Use `check_cloud_integration` to list or show specific integration
2. Check `state.ok` and `lastSuccessfulTime` fields
3. Verify `enabled` is 1 and relevant scan settings are configured
4. Review `state.details.message` for any error messages

### Investigate vulnerability assessments
1. Use `get_host_vulnerability_assessments` to get all assessments for a host
2. Filter by collector type, provider, or severity as needed
3. Group results by evalGuid to see unique assessments
4. Check assessment timestamps to verify recent scans

### Compare agent vs agentless scanning
1. Use `compare_assessment_types` for a specific machine
2. Review counts of agent vs agentless assessments
3. Check if both types are present or only one
4. Verify data completeness in each assessment type

### Find hosts with specific CVE
1. Use `list_hosts_with_cve` with the CVE ID
2. Review affected hosts and severity
3. Use `get_host_vulnerability_assessments` for detailed assessment data

### Investigate alerts
1. Use `list_alerts` to see recent alerts
2. Filter by severity or type as needed
3. Use `show_alert` to get detailed information about specific alerts
4. Review affected resources and recommendations

### Query custom data
1. Use `list_datasources` to see available data sources
2. Use `preview_datasource` to explore data structure
3. Use `list_queries` to find relevant queries
4. Use `run_query` to execute queries and get results

### Agent investigation
1. Use `list_agents` to see all registered agents
2. Review OS, architecture, and status information
3. Cross-reference with vulnerability assessments to verify agent coverage
4. Check for any agents with unusual status or configuration

## Building CSPM/Compliance LQL Queries

This section covers how to build custom CSPM policies using Lacework Query Language (LQL) to query AWS inventory data.

### LQL Query Structure

All LQL queries follow this structure:
```
{
    source {
        DATASOURCE_NAME alias
    }
    filter {
        <conditions>
    }
    return distinct {
        <fields>
    }
}
```

### Key LQL Syntax Rules

1. **Operators**: Use `=`, `<>` (not equal), `>`, `<`, `>=`, `<=`
   - Do NOT use `!=` - LQL uses `<>` for not equal
2. **Strings**: Use single quotes `'value'` not double quotes
3. **JSON Path**: Access nested JSON with colon notation: `RESOURCE_CONFIG:Field.SubField`
4. **Null checks**: Use `IS NULL` and `IS NOT NULL`
5. **Boolean logic**: Use `AND`, `OR`, `NOT`
6. **Subqueries**: Use `IN` with nested source blocks for set operations

### Common AWS Datasources

| Resource Level | Datasource | Description |
|----------------|------------|-------------|
| **Account** | `LW_CFG_AWS_ACCOUNTS` | All AWS accounts |
| **Account** | `LW_CFG_AWS_ACCOUNT_GET_ALTERNATE_CONTACT` | Account alternate contacts |
| **EC2** | `LW_CFG_AWS_EC2_INSTANCES` | EC2 instances |
| **EC2** | `LW_CFG_AWS_EC2_SECURITY_GROUPS` | Security groups |
| **EC2** | `LW_CFG_AWS_EC2_VOLUMES` | EBS volumes |
| **S3** | `LW_CFG_AWS_S3` | S3 buckets |
| **S3** | `LW_CFG_AWS_S3_GET_BUCKET_ENCRYPTION` | Bucket encryption config |
| **IAM** | `LW_CFG_AWS_IAM_USERS` | IAM users |
| **IAM** | `LW_CFG_AWS_IAM_ROLES` | IAM roles |
| **IAM** | `LW_CFG_AWS_IAM_POLICIES` | IAM policies |
| **Lambda** | `LW_CFG_AWS_LAMBDA` | Lambda functions |
| **RDS** | `LW_CFG_AWS_RDS_DB_INSTANCES` | RDS instances |

### Standard Return Fields for Compliance Policies

All compliance queries should return these fields:
```
return distinct {
    ACCOUNT_ID,
    RESOURCE_ID as RESOURCE_KEY,   -- or ACCOUNT_ID for account-level
    RESOURCE_REGION,
    RESOURCE_TYPE,
    SERVICE,
    '<FailureReason>' as COMPLIANCE_FAILURE_REASON
}
```

### Query Patterns

#### Pattern 1: Account-Level - "NOT IN" Subquery

Use when checking accounts that lack a specific configuration. Example: accounts without security contacts.

```lql
{
    source {
        LW_CFG_AWS_ACCOUNTS account
    }
    filter {
        not (account.ACCOUNT_ID in {
            source {
                LW_CFG_AWS_ACCOUNT_GET_ALTERNATE_CONTACT
            }
            filter {
                RESOURCE_CONFIG:AlternateContact.AlternateContactType = 'SECURITY'
                AND RESOURCE_CONFIG:AlternateContact.Name is not null
                AND RESOURCE_CONFIG:AlternateContact.Name <> ''
            }
            return distinct {
                ACCOUNT_ID
            }
        })
    }
    return distinct {
        account.ACCOUNT_ALIAS,
        account.ACCOUNT_ID,
        account.ACCOUNT_ID as RESOURCE_KEY,
        account.RESOURCE_REGION,
        account.RESOURCE_TYPE,
        account.SERVICE,
        'SecurityContactMissingOrIncomplete' as COMPLIANCE_FAILURE_REASON
    }
}
```

#### Pattern 2: Resource-Level - Direct Filter

Use when checking individual resources. Example: EC2 instances without IMDSv2.

```lql
{
    source {
        LW_CFG_AWS_EC2_INSTANCES instance
    }
    filter {
        instance.RESOURCE_CONFIG:MetadataOptions.HttpTokens <> 'required'
    }
    return distinct {
        instance.ACCOUNT_ID,
        instance.RESOURCE_ID as RESOURCE_KEY,
        instance.RESOURCE_REGION,
        instance.RESOURCE_TYPE,
        instance.SERVICE,
        'IMDSv2NotEnforced' as COMPLIANCE_FAILURE_REASON
    }
}
```

#### Pattern 3: Security Group Rules - Array Iteration

Use `array_to_rows()` to iterate through arrays like security group rules.

```lql
{
    source {
        LW_CFG_AWS_EC2_SECURITY_GROUPS sg
    }
    filter {
        value_exists(
            array_to_rows(sg.RESOURCE_CONFIG:IpPermissions),
            ip,
            value_exists(
                array_to_rows(ip:IpRanges),
                range,
                range:CidrIp = '0.0.0.0/0'
            )
            AND ip:FromPort <= 22
            AND ip:ToPort >= 22
        )
    }
    return distinct {
        sg.ACCOUNT_ID,
        sg.RESOURCE_ID as RESOURCE_KEY,
        sg.RESOURCE_REGION,
        sg.RESOURCE_TYPE,
        sg.SERVICE,
        'SSHOpenToWorld' as COMPLIANCE_FAILURE_REASON
    }
}
```

#### Pattern 4: Cross-Resource Join with `with` Keyword

Use `with` to join related datasources. Example: CloudTrail trails with event selectors.

```lql
{
    source {
        LW_CFG_AWS_ACCOUNTS
    }
    filter {
        not (ACCOUNT_ID in {
            source {
                LW_CFG_AWS_CLOUDTRAIL trail
                with LW_CFG_AWS_CLOUDTRAIL_GET_EVENT_SELECTORS selectors,
                array_to_rows(selectors.RESOURCE_CONFIG:EventSelectors) as (event_selectors)
            }
            filter {
                trail.RESOURCE_CONFIG:IsMultiRegionTrail = true
                and event_selectors:ReadWriteType = 'All'
                and event_selectors:IncludeManagementEvents = true
            }
            return distinct {
                trail.ACCOUNT_ID
            }
        })
    }
    return distinct {
        ACCOUNT_ALIAS,
        ACCOUNT_ID,
        ACCOUNT_ID as RESOURCE_KEY,
        RESOURCE_REGION,
        RESOURCE_TYPE,
        SERVICE,
        'NoMultiRegionTrailWithManagementEvents' as COMPLIANCE_FAILURE_REASON
    }
}
```

**Key syntax**:
- `with` joins related datasources (auto-matches on RESOURCE_ID/ACCOUNT_ID)
- `array_to_rows(field) as (alias)` iterates array elements
- Access array element fields with `alias:FieldName`

#### Pattern 5: Type Casting and Empty Config Check

Use `::string` to cast JSON values for comparison, and `'{}'` to check for empty config.

```lql
{
    source {
        LW_CFG_AWS_S3 buckets
        with LW_CFG_AWS_S3_GET_BUCKET_LOGGING bucket
    }
    filter {
        bucket.RESOURCE_CONFIG = '{}'
        and bucket.RESOURCE_ID in {
            source {
                LW_CFG_AWS_CLOUDTRAIL
            }
            return distinct {
                RESOURCE_CONFIG:S3BucketName::string as bucket_name
            }
        }
    }
    return distinct {
        buckets.ACCOUNT_ID,
        buckets.ARN as RESOURCE_KEY,
        buckets.RESOURCE_REGION,
        buckets.RESOURCE_TYPE,
        buckets.SERVICE,
        'CloudTrailS3BucketLoggingNotEnabled' as COMPLIANCE_FAILURE_REASON
    }
}
```

**Key syntax**:
- `RESOURCE_CONFIG = '{}'` checks for empty JSON config
- `::string` casts JSON path to string for `in` comparison
- Useful when checking if a config exists vs is empty

### Exploring Datasources

Before writing a query, explore the datasource structure:

```bash
# List all AWS datasources
lacework query list-sources --json | jq -r '.[].name' | grep -i aws

# Show datasource schema
lacework query show-source LW_CFG_AWS_EC2_INSTANCES --json

# Preview sample data from datasource
lacework query preview-source LW_CFG_AWS_EC2_INSTANCES --json
```

### Testing Queries

Test queries using stdin with heredoc:

```bash
cat << 'EOF' | lacework query run --start "-24h" --json \
  --account "$ACCOUNT" \
  --subaccount "$SUBACCOUNT" \
  --api_key "$API_KEY" \
  --api_secret "$API_SECRET"
{
  "queryId": "temp",
  "queryText": "{ source { LW_CFG_AWS_ACCOUNTS } return { ACCOUNT_ID, ACCOUNT_ALIAS } }"
}
EOF
```

### LQL Functions Reference

| Function | Description | Example |
|----------|-------------|---------|
| `array_to_rows(arr)` | Iterate array elements | `array_to_rows(RESOURCE_CONFIG:Tags)` |
| `value_exists(arr, alias, condition)` | Check if any element matches | `value_exists(array_to_rows(Tags), t, t:Key = 'Name')` |
| `length(arr)` | Array length | `length(RESOURCE_CONFIG:SecurityGroups)` |
| `contains(str, substr)` | String contains | `contains(RESOURCE_ID, 'prod')` |
| `starts_with(str, prefix)` | String starts with | `starts_with(ARN, 'arn:aws:')` |
| `ends_with(str, suffix)` | String ends with | `ends_with(RESOURCE_ID, '-dev')` |
| `regex_match(str, pattern)` | Regex match | `regex_match(RESOURCE_ID, '^i-[a-z0-9]+$')` |

### Documentation Links

- LQL Reference: https://docs.fortinet.com/document/forticnapp/latest/lql-reference/598361/lql-overview
- LQL Operators: https://docs.fortinet.com/document/forticnapp/latest/lql-reference/754354/lql-operators
- LQL Functions: https://docs.fortinet.com/document/forticnapp/latest/lql-reference/486918/lql-functions
- Datasource Metadata: https://docs.fortinet.com/document/forticnapp/latest/lql-reference/771173/datasource-metadata

## Related Documentation

- Lacework CLI Reference: https://docs.fortinet.com/document/forticnapp/latest/cli-reference
- Lacework API Reference: https://docs.fortinet.com/document/forticnapp/latest/api-reference
- Interactive API Docs: https://api.lacework.net/api/v2/docs (use this for endpoint discovery)

## API Endpoint Reference

### Working Endpoints

- `GET /api/v2/Reports` - Extract compliance report data including policy inventories
- `GET /api/v2/CloudAccounts` - List cloud account integrations and get account IDs
- `GET /api/v2/Configs/AzureSubscriptions` - Get Azure subscription information
- `POST /api/v2/Vulnerabilities/Hosts/search` - Search vulnerability assessments
- `GET /api/v2/Queries` - List and execute LQL queries

### Broken/Non-Functional Endpoints

- `GET /api/v2/ReportDefinitions` - Does not show recent definitions (broken, use Reports endpoint instead)
