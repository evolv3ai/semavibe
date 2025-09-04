#!/bin/bash
# Wrapper script for Terraform to ensure OCI config is found in Semaphore container

# Set the OCI config file location for the container environment
export OCI_CLI_CONFIG_FILE="/home/semaphore/.oci/config"

# Debug: Check if the OCI config file exists
if [ -f "$OCI_CLI_CONFIG_FILE" ]; then
    echo "✓ OCI config file found at: $OCI_CLI_CONFIG_FILE"
    echo "✓ Checking OCI config contents..."
    
    # Check if the DEFAULT profile exists and has required fields
    if grep -q "\[DEFAULT\]" "$OCI_CLI_CONFIG_FILE"; then
        echo "✓ DEFAULT profile found"
        
        # Check for required fields
        for field in tenancy user fingerprint key_file region; do
            if grep -q "^${field}=" "$OCI_CLI_CONFIG_FILE"; then
                echo "  ✓ ${field} is configured"
            else
                echo "  ✗ ${field} is missing!"
            fi
        done
        
        # Check if the private key file exists
        KEY_FILE=$(grep "^key_file=" "$OCI_CLI_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$KEY_FILE" ]; then
            # Expand tilde if present
            KEY_FILE="${KEY_FILE/#\~/$HOME}"
            if [ -f "$KEY_FILE" ]; then
                echo "  ✓ Private key file exists at: $KEY_FILE"
            else
                echo "  ✗ Private key file not found at: $KEY_FILE"
                echo "    This is likely the cause of the authentication error!"
            fi
        fi
    else
        echo "✗ DEFAULT profile not found in OCI config"
    fi
else
    echo "✗ OCI config file not found at: $OCI_CLI_CONFIG_FILE"
    echo "  Please ensure OCI credentials are properly mounted in the container"
fi

echo ""
echo "Running Terraform with OCI_CLI_CONFIG_FILE=$OCI_CLI_CONFIG_FILE"
echo "----------------------------------------"

# Pass all arguments to terraform
terraform "$@"