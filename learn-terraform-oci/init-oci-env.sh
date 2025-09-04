#!/bin/bash
# Initialize OCI environment for learn-terraform-oci in Semaphore container

echo "=== OCI Environment Initialization for learn-terraform-oci ==="
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
    
    # Check for the learn-terraform profile (required by main.tf)
    PROFILE="learn-terraform"
    echo ""
    echo "Checking for profile: $PROFILE"
    
    if grep -q "\[$PROFILE\]" "$OCI_CLI_CONFIG_FILE"; then
        echo "✓ Profile '$PROFILE' found"
    else
        echo "✗ Profile '$PROFILE' not found!"
        echo ""
        echo "Checking for DEFAULT profile to copy from..."
        
        if grep -q "\[DEFAULT\]" "$OCI_CLI_CONFIG_FILE"; then
            echo "✓ DEFAULT profile found"
            echo "  Creating '$PROFILE' profile from DEFAULT..."
            
            # Backup the original config
            cp "$OCI_CLI_CONFIG_FILE" "${OCI_CLI_CONFIG_FILE}.bak"
            
            # Extract DEFAULT profile and append as learn-terraform
            echo "" >> "$OCI_CLI_CONFIG_FILE"
            echo "[$PROFILE]" >> "$OCI_CLI_CONFIG_FILE"
            
            # Copy all settings from DEFAULT profile
            awk '/\[DEFAULT\]/,/^\[/ {
                if ($0 !~ /^\[/ && NF > 0) print $0
            }' "${OCI_CLI_CONFIG_FILE}.bak" | while read -r line; do
                echo "$line" >> "$OCI_CLI_CONFIG_FILE"
            done
            
            echo "✓ Created '$PROFILE' profile"
        else
            echo "✗ No DEFAULT profile found to copy from"
            echo "  Please ensure OCI credentials are properly configured"
            exit 1
        fi
    fi
    
    # Parse the key_file path from the profile
    KEY_FILE=$(awk "/\[$PROFILE\]/,/^\[/ { if (/^key_file=/) print }" "$OCI_CLI_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ' | head -1)
    
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
                # Update the key_file path for the learn-terraform profile
                sed -i "/\[$PROFILE\]/,/^\[/ s|^key_file=.*|key_file=$FOUND_KEY|" "$OCI_CLI_CONFIG_FILE"
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
    
    # Since auth = "SecurityToken" is used, check for security_token_file
    echo ""
    echo "Checking SecurityToken authentication..."
    
    # The auth method in main.tf is SecurityToken, which requires a session token
    # This is typically used with resource principal or instance principal auth
    # For API key auth, we need to modify the provider configuration
    
    echo "  Note: main.tf uses auth='SecurityToken' which requires session tokens"
    echo "  For API key authentication, the provider configuration needs to be updated"
    
    # Verify all required fields are present for the profile
    echo ""
    echo "Verifying OCI configuration for profile '$PROFILE'..."
    MISSING_FIELDS=()
    
    for field in tenancy user fingerprint key_file region; do
        if awk "/\[$PROFILE\]/,/^\[/ { if (/^${field}=/) exit 0; } END { exit 1 }" "$OCI_CLI_CONFIG_FILE"; then
            echo "  ✓ ${field}: configured"
        else
            echo "  ✗ ${field}: missing"
            MISSING_FIELDS+=("$field")
        fi
    done
    
    if [ ${#MISSING_FIELDS[@]} -gt 0 ]; then
        echo ""
        echo "ERROR: Missing required OCI configuration fields in profile '$PROFILE': ${MISSING_FIELDS[*]}"
        exit 1
    fi
    
    # Set proper permissions on config file
    chmod 600 "$OCI_CLI_CONFIG_FILE" 2>/dev/null || true
    
    echo ""
    echo "✓ OCI environment initialized successfully"
    echo "  OCI_CLI_CONFIG_FILE=$OCI_CLI_CONFIG_FILE"
    echo "  Profile: $PROFILE"
    
else
    echo "ℹ Not running in container environment"
    echo "  Using default OCI config location"
fi

echo ""
echo "=== Environment ready for Terraform ==="
echo ""

# Export for child processes
export OCI_CLI_CONFIG_FILE