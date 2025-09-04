# OCI Authentication Fix for learn-terraform-oci

## Problem Resolved
The Terraform task was failing with:
```
Error: can not create client, bad configuration: did not find a proper configuration for private key
```

## Issues Identified
1. **Wrong authentication method**: The `main.tf` was using `auth = "SecurityToken"` which requires session tokens, not API keys
2. **Missing profile**: The config expects profile `learn-terraform` but container has `DEFAULT`
3. **Config file location**: OCI provider couldn't find config at `/home/semaphore/.oci/config`

## Solutions Applied

### 1. Fixed main.tf
- Removed `auth = "SecurityToken"` line to use default API key authentication
- Kept `config_file_profile = "learn-terraform"`

### 2. Created init-oci-env.sh
This script:
- Sets `OCI_CLI_CONFIG_FILE` environment variable
- Creates `learn-terraform` profile from `DEFAULT` if missing
- Validates and fixes private key paths
- Verifies all required fields

### 3. Updated Semaphore Template Commands
The template should now run:
```bash
#!/bin/bash
set -e

# Initialize OCI environment
chmod +x ./init-oci-env.sh
source ./init-oci-env.sh

# Run Terraform
terraform init -input=false
terraform plan
```

## How to Use

### Option 1: With initialization script (Recommended)
```bash
# Set up environment and run Terraform
source ./init-oci-env.sh
terraform init
terraform plan
terraform apply
```

### Option 2: Manual environment setup
```bash
# Set the config file location
export OCI_CLI_CONFIG_FILE="/home/semaphore/.oci/config"

# Run Terraform
terraform init
terraform plan
terraform apply
```

## Verification Checklist

Before running:
1. ✅ OCI config exists at `/home/semaphore/.oci/config`
2. ✅ Private key file exists (e.g., `/home/semaphore/.oci/oci_api_key.pem`)
3. ✅ Config has profile `[learn-terraform]` or `[DEFAULT]`
4. ✅ Profile contains: tenancy, user, fingerprint, key_file, region
5. ✅ `main.tf` doesn't have `auth = "SecurityToken"`

## Files Modified/Created
- **main.tf** - Removed SecurityToken auth method
- **init-oci-env.sh** - Environment setup script
- **README_FIX.md** - This documentation

## Next Steps
1. Commit these changes to the repository
2. Push to GitHub
3. Re-run the Semaphore task

The initialization script will automatically handle profile creation and path corrections.