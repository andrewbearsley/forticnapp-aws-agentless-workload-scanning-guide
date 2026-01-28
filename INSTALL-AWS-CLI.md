# Installing and Configuring AWS CLI

## Installation

### macOS

Install using Homebrew:
```bash
brew install awscli
```

### Windows

**Option 1 - Chocolatey:**
```powershell
choco install awscli
```

**Option 2 - MSI Installer:**
1. Download the AWS CLI MSI installer from https://aws.amazon.com/cli/
2. Run the installer
3. Follow the installation prompts

### Verify Installation

```bash
aws --version
```

## Configuration

### Configure AWS Credentials

```bash
aws configure
```

You will be prompted for:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name (e.g., `ap-southeast-2`)
- Default output format (e.g., `json`)

### Using AWS SSO (Recommended for Organizations)

If your organization uses AWS IAM Identity Center (SSO):

```bash
aws configure sso
```

Then login with:
```bash
aws sso login --profile <profile-name>
```

### Verify Access

```bash
aws sts get-caller-identity
```

### List Available Profiles

```bash
aws configure list-profiles
```

To use a specific profile:
```bash
export AWS_PROFILE=<profile-name>
```

Or specify per-command:
```bash
aws s3 ls --profile <profile-name>
```

## Reference

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/latest/userguide/)
- [Configuring the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
