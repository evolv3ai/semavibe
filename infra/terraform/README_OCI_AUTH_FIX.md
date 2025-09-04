# OCI Authentication Fix for Semaphore Terraform Tasks

## Problem
The Terraform OCI provider was failing with the error:
```
Error: can not create client, bad configuration: did not find a proper configuration for private key
```

This occurs because the OCI provider cannot locate the configuration file or private key in the Semaphore container environment.

## Root Cause
1. The OCI configuration is mounted at `/home/semaphore/.oci/config` in the container
2. The Terraform OCI provider by default looks for config at `~/.oci/config` 
3. The private key path in the config file may not be correctly pointing to the mounted key location

## Solution

### Option 1: Use the initialization script (Recommended)
Before running Terraform commands, source the initialization script:

```bash
# In your Semaphore template, add this before terraform commands:
source ./init-oci-env.sh
terraform init -input=false
terraform apply -auto-approve
```

The `init-oci-env.sh` script will:
- Set the `OCI_CLI_CONFIG_FILE` environment variable
- Verify the OCI configuration exists
- Check and fix the private key path if needed
- Validate all required fields are present

### Option 2: Use the wrapper script
Replace direct `terraform` commands with the wrapper:

```bash
# Instead of: terraform init
./terraform-wrapper.sh init -input=false

# Instead of: terraform apply
./terraform-wrapper.sh apply -auto-approve
```

### Option 3: Set environment variable manually
Add this to your Semaphore template:

```bash
export OCI_CLI_CONFIG_FILE="/home/semaphore/.oci/config"
terraform init -input=false
terraform apply -auto-approve
```

## Updated Semaphore Template Configuration

Update your Semaphore template (ID: 10) with these commands:

```yaml
# Template: learn-terraform-test
# Working Directory: infra/terraform

commands:
  - name: Initialize OCI Environment
    cmd: |
      chmod +x ./init-oci-env.sh
      source ./init-oci-env.sh
  
  - name: Terraform Init
    cmd: terraform init -input=false
  
  - name: Terraform Apply
    cmd: terraform apply -auto-approve
```

Or as a single command block:

```bash
#!/bin/bash
set -e

# Initialize OCI environment
chmod +x ./init-oci-env.sh
source ./init-oci-env.sh

# Run Terraform
terraform init -input=false
terraform apply -auto-approve
```

## Verification Checklist

Before running the template, ensure:

1. **OCI Config is mounted**: The `/home/semaphore/.oci/config` file exists in the container
2. **Private key is mounted**: The private key file (e.g., `/home/semaphore/.oci/oci_api_key.pem`) exists
3. **Config has all fields**: The config contains:
   - `tenancy`
   - `user`
   - `fingerprint`
   - `key_file` (pointing to the correct path)
   - `region`

## Debugging

If issues persist, run the diagnostic script:

```bash
./terraform-wrapper.sh version
```

This will output diagnostic information about the OCI configuration before running Terraform.

## Files Created

1. **`init-oci-env.sh`**: Environment initialization script that sets up OCI authentication
2. **`terraform-wrapper.sh`**: Wrapper script that sets environment and provides diagnostics
3. **`README_OCI_AUTH_FIX.md`**: This documentation file

## Next Steps

1. Commit these files to the repository
2. Update the Semaphore template to use the initialization script
3. Re-run the Terraform task

## Additional Notes

- The scripts automatically handle path corrections for the private key
- They work specifically in the Semaphore container environment
- Outside the container, standard OCI CLI configuration will be used