#!/bin/bash
set -e

# Set OCI environment
export OCI_CLI_CONFIG_FILE="/home/semaphore/.oci/config"

# Fix paths in config
cp $OCI_CLI_CONFIG_FILE /tmp/oci_config
sed -i 's|C:\\Users\\[^\\]*\\.oci|/home/semaphore/.oci|g' /tmp/oci_config
sed -i 's|~/.oci|/home/semaphore/.oci|g' /tmp/oci_config
export OCI_CLI_CONFIG_FILE="/tmp/oci_config"

# Navigate to Terraform directory
cd learn-terraform-oci

# Run Terraform
terraform init -input=false
terraform plan
# terraform apply -auto-approve  # Uncomment to apply
