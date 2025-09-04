#!/bin/bash
# Initialize OCI environment for Terraform in Semaphore container

echo "=== OCI Environment Initialization ==="
echo ""

# Set the OCI config file location
export OCI_CLI_CONFIG_FILE="/home/semaphore/.oci/config"

# Check if running in container (Semaphore environment)
if [ -f /.dockerenv ] || [ -n "$SEMAPHORE_PROJECT_ID" ]; then
    echo "✓ Running in Semaphore container environment"
    
    # Ensure the OCI config directory exists
    if [ ! -d "/home/semaphore/.oci" ]; then
        echo "✗ OCI config directory not found at /home/semaphore/.oci"
        echo "  Creating directory..."
        mkdir -p /home/semaphore/.oci
    fi
    
    # Check if config file exists
    if [ ! -f "$OCI_CLI_CONFIG_FILE" ]; then
        echo "✗ OCI config file not found"
        echo ""
        echo "ERROR: OCI credentials are not properly configured."
        echo "Please ensure that:"
        echo "1. OCI config is stored in Semaphore Key Store"
        echo "2. The config is properly mounted to /home/semaphore/.oci/config"
        echo "3. The private key file is accessible"
        exit 1
    fi
    
    echo "✓ OCI config file found at: $OCI_CLI_CONFIG_FILE"
    
    # Parse the key_file path from config
    KEY_FILE=$(grep "^key_file=" "$OCI_CLI_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ' | head -1)
    
    if [ -n "$KEY_FILE" ]; then
        # Handle relative paths and tilde expansion
        if [[ "$KEY_FILE" == ~* ]]; then
            KEY_FILE="${KEY_FILE/#\~/$HOME}"
        elif [[ "$KEY_FILE" != /* ]]; then
            # Relative path - make it relative to .oci directory
            KEY_FILE="/home/semaphore/.oci/$KEY_FILE"
        fi
        
        echo "  Checking private key at: $KEY_FILE"
        
        if [ ! -f "$KEY_FILE" ]; then
            echo "  ✗ Private key file not found!"
            echo ""
            echo "  Attempting to fix the key_file path..."
            
            # Common locations to check
            POSSIBLE_KEYS=(
                "/home/semaphore/.oci/oci_api_key.pem"
                "/home/semaphore/.oci/key.pem"
                "/home/semaphore/.oci/private_key.pem"
                "$HOME/.oci/oci_api_key.pem"
                "$HOME/.oci/key.pem"
            )
            
            FOUND_KEY=""
            for key_path in "${POSSIBLE_KEYS[@]}"; do
                if [ -f "$key_path" ]; then
                    echo "  ✓ Found private key at: $key_path"
                    FOUND_KEY="$key_path"
                    break
                fi
            done
            
            if [ -n "$FOUND_KEY" ]; then
                echo "  Updating OCI config to use correct key path..."
                # Create a backup
                cp "$OCI_CLI_CONFIG_FILE" "${OCI_CLI_CONFIG_FILE}.bak"
                # Update the key_file path
                sed -i "s|^key_file=.*|key_file=$FOUND_KEY|" "$OCI_CLI_CONFIG_FILE"
                echo "  ✓ Updated key_file path in config"
            else
                echo "  ✗ Could not find private key file in any expected location"
                echo ""
                echo "  Please ensure the OCI private key is properly mounted."
                exit 1
            fi
        else
            echo "  ✓ Private key file exists"
            # Ensure proper permissions
            chmod 600 "$KEY_FILE" 2>/dev/null || true
        fi
    fi
    
    # Verify all required fields are present
    echo ""
    echo "Verifying OCI configuration..."
    MISSING_FIELDS=()
    
    for field in tenancy user fingerprint key_file region; do
        if grep -q "^${field}=" "$OCI_CLI_CONFIG_FILE"; then
            VALUE=$(grep "^${field}=" "$OCI_CLI_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ' | head -1)
            if [ -n "$VALUE" ]; then
                echo "  ✓ ${field}: configured"
            else
                echo "  ✗ ${field}: empty value"
                MISSING_FIELDS+=("$field")
            fi
        else
            echo "  ✗ ${field}: missing"
            MISSING_FIELDS+=("$field")
        fi
    done
    
    if [ ${#MISSING_FIELDS[@]} -gt 0 ]; then
        echo ""
        echo "ERROR: Missing required OCI configuration fields: ${MISSING_FIELDS[*]}"
        exit 1
    fi
    
    # Set proper permissions on config file
    chmod 600 "$OCI_CLI_CONFIG_FILE" 2>/dev/null || true
    
    echo ""
    echo "✓ OCI environment initialized successfully"
    echo "  OCI_CLI_CONFIG_FILE=$OCI_CLI_CONFIG_FILE"
    
else
    echo "ℹ Not running in container environment"
    echo "  Using default OCI config location"
fi

echo ""
echo "=== Environment ready for Terraform ==="
echo ""

# Export for child processes
export OCI_CLI_CONFIG_FILE