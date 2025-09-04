#!/bin/bash
set -e

echo "================================================"
echo "OCI Terraform Universal Setup"
echo "================================================"
echo ""

# Debug: Show environment
echo "Environment variables:"
env | grep -E "OCI|TERRAFORM" || true
echo ""

# Set OCI environment
export OCI_CLI_CONFIG_FILE="${OCI_CLI_CONFIG_FILE:-/home/semaphore/.oci/config}"
echo "Using OCI config: $OCI_CLI_CONFIG_FILE"

# Check if config exists
if [ ! -f "$OCI_CLI_CONFIG_FILE" ]; then
    echo "ERROR: OCI config not found at $OCI_CLI_CONFIG_FILE"
    echo "Contents of /home/semaphore/.oci/:"
    ls -la /home/semaphore/.oci/ 2>/dev/null || echo "Directory not found"
    exit 1
fi

echo "✓ OCI config found"
echo ""

# Create working copy and fix paths
echo "Fixing paths in OCI config..."
cp "$OCI_CLI_CONFIG_FILE" /tmp/oci_config_fixed

# Fix Windows paths
sed -i 's|C:\\Users\\[^\\]*\\.oci\\|/home/semaphore/.oci/|g' /tmp/oci_config_fixed
sed -i 's|C:\\Users\\[^\\]*\\.oci/|/home/semaphore/.oci/|g' /tmp/oci_config_fixed

# Fix Unix paths
sed -i 's|~/.oci/|/home/semaphore/.oci/|g' /tmp/oci_config_fixed
sed -i 's|/Users/[^/]*/.oci/|/home/semaphore/.oci/|g' /tmp/oci_config_fixed

# Remove backslashes
sed -i 's|\\|/|g' /tmp/oci_config_fixed

export OCI_CLI_CONFIG_FILE="/tmp/oci_config_fixed"
echo "✓ Paths fixed"
echo ""

# Show available profiles
echo "Available OCI profiles:"
grep "^\[" "$OCI_CLI_CONFIG_FILE" || echo "No profiles found"
echo ""

# Navigate to Terraform directory
echo "Navigating to Terraform directory..."
if [ -d "learn-terraform-oci" ]; then
    cd learn-terraform-oci
elif [ -d "." ]; then
    # Already in the right directory
    echo "Already in learn-terraform-oci directory"
else
    echo "ERROR: Cannot find Terraform directory"
    exit 1
fi

echo "Current directory: $(pwd)"
echo "Files:"
ls -la *.tf 2>/dev/null || echo "No .tf files found"
echo ""

# Check Terraform installation
echo "Checking Terraform..."
which terraform || (echo "ERROR: Terraform not found" && exit 1)
terraform version
echo ""

# Initialize Terraform
echo "Initializing Terraform..."
terraform init -input=false
echo "✓ Terraform initialized"
echo ""

# Validate
echo "Validating Terraform configuration..."
terraform validate
echo "✓ Configuration valid"
echo ""

# Plan
echo "Creating Terraform plan..."
# Use environment variable for compartment_id if terraform.tfvars doesn't exist
if [ ! -f terraform.tfvars ]; then
    if [ -z "$TF_VAR_compartment_id" ]; then
        echo "⚠️  No terraform.tfvars found and TF_VAR_compartment_id not set"
        echo "   Using example compartment_id for demo purposes"
        export TF_VAR_compartment_id="ocid1.compartment.oc1..aaaaaaaaq3qy3dmnci7vbc6vdzwaptmz6m4u667exhuc2zem4pde4f4fulea"
    fi
fi
terraform plan -input=false
echo ""
echo "✓ Plan complete"
echo ""

echo "================================================"
echo "Task completed successfully!"
echo "To apply: terraform apply -auto-approve"
echo "================================================"