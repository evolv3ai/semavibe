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

# Extract DEFAULT values for missing fields
DEFAULT_USER=$(grep -A10 "^\[DEFAULT\]" /tmp/oci_config_fixed | grep "^user" | head -1 | cut -d'=' -f2 | tr -d ' ')
DEFAULT_TENANCY=$(grep -A10 "^\[DEFAULT\]" /tmp/oci_config_fixed | grep "^tenancy" | head -1 | cut -d'=' -f2 | tr -d ' ')
DEFAULT_REGION=$(grep -A10 "^\[DEFAULT\]" /tmp/oci_config_fixed | grep "^region" | head -1 | cut -d'=' -f2 | tr -d ' ')

# If no region in DEFAULT, use us-ashburn-1
if [ -z "$DEFAULT_REGION" ]; then
    DEFAULT_REGION="us-ashburn-1"
fi

echo "Fixing incomplete profiles..."
# Create a new config with complete profiles
{
    current_profile=""
    has_user=false
    has_tenancy=false
    has_region=false
    
    while IFS= read -r line; do
        # Check if this is a profile header
        if [[ "$line" =~ ^\[.*\]$ ]]; then
            # If we were processing a profile, add missing fields
            if [ -n "$current_profile" ]; then
                if [ "$has_user" = false ] && [ -n "$DEFAULT_USER" ]; then
                    echo "user=$DEFAULT_USER"
                fi
                if [ "$has_tenancy" = false ] && [ -n "$DEFAULT_TENANCY" ]; then
                    echo "tenancy=$DEFAULT_TENANCY"
                fi
                if [ "$has_region" = false ] && [ -n "$DEFAULT_REGION" ]; then
                    echo "region=$DEFAULT_REGION"
                fi
            fi
            # Start new profile
            current_profile="$line"
            has_user=false
            has_tenancy=false
            has_region=false
            echo "$line"
        else
            # Check what field this is
            if [[ "$line" =~ ^user= ]]; then
                has_user=true
            elif [[ "$line" =~ ^tenancy= ]]; then
                has_tenancy=true
            elif [[ "$line" =~ ^region= ]]; then
                has_region=true
            fi
            echo "$line"
        fi
    done < /tmp/oci_config_fixed
    
    # Handle the last profile
    if [ -n "$current_profile" ]; then
        if [ "$has_user" = false ] && [ -n "$DEFAULT_USER" ]; then
            echo "user=$DEFAULT_USER"
        fi
        if [ "$has_tenancy" = false ] && [ -n "$DEFAULT_TENANCY" ]; then
            echo "tenancy=$DEFAULT_TENANCY"
        fi
        if [ "$has_region" = false ] && [ -n "$DEFAULT_REGION" ]; then
            echo "region=$DEFAULT_REGION"
        fi
    fi
} > /tmp/oci_config_complete

mv /tmp/oci_config_complete /tmp/oci_config_fixed

# The mounted file is read-only, so we'll use the temp file
export OCI_CLI_CONFIG_FILE="/tmp/oci_config_fixed"
echo "✓ Paths and profiles fixed - using: $OCI_CLI_CONFIG_FILE"
echo ""

# Validate that key files actually exist
echo "Validating key files..."
while IFS= read -r line; do
    if [[ "$line" =~ ^key_file= ]]; then
        key_path=$(echo "$line" | cut -d'=' -f2 | tr -d ' ')
        if [ ! -f "$key_path" ]; then
            echo "⚠️  WARNING: Key file not found: $key_path"
            echo "   Checking for alternative locations..."
            
            # Try to find the key file in common locations
            key_filename=$(basename "$key_path")
            found_key=""
            
            # Check common locations
            for dir in /home/semaphore/.oci /home/semaphore/.oci/sessions/*/; do
                if [ -f "$dir/$key_filename" ]; then
                    found_key="$dir/$key_filename"
                    echo "   ✓ Found key at: $found_key"
                    # Update the config with the correct path
                    sed -i "s|$key_path|$found_key|g" "$OCI_CLI_CONFIG_FILE"
                    break
                fi
            done
            
            if [ -z "$found_key" ]; then
                echo "   ❌ ERROR: Could not find key file: $key_filename"
                echo "   Available files in /home/semaphore/.oci:"
                ls -la /home/semaphore/.oci/ 2>/dev/null | grep -E "\.(pem|key)" || echo "   No .pem or .key files found"
                echo ""
                echo "   This profile will not work with Terraform."
            fi
        else
            echo "   ✓ Key file exists: $key_path"
        fi
    fi
done < "$OCI_CLI_CONFIG_FILE"
echo ""

# Debug: Show the fixed config content (first few lines)
echo "Fixed config preview:"
head -n 30 "$OCI_CLI_CONFIG_FILE"
echo ""

# Show available profiles
echo "Available OCI profiles:"
grep "^\[" "$OCI_CLI_CONFIG_FILE" || echo "No profiles found"
echo ""

# Check which profile to use
if [ -n "$OCI_CONFIG_PROFILE" ]; then
    echo "Using specified profile: $OCI_CONFIG_PROFILE"
else
    # Default to DEFAULT profile for Terraform
    export OCI_CONFIG_PROFILE="DEFAULT"
    echo "No profile specified, using: DEFAULT"
fi

# Verify the profile has required fields
echo "Verifying profile configuration..."
profile_user=$(grep -A10 "^\[$OCI_CONFIG_PROFILE\]" "$OCI_CLI_CONFIG_FILE" | grep "^user" | head -1)
profile_key=$(grep -A10 "^\[$OCI_CONFIG_PROFILE\]" "$OCI_CLI_CONFIG_FILE" | grep "^key_file" | head -1)
profile_token=$(grep -A10 "^\[$OCI_CONFIG_PROFILE\]" "$OCI_CLI_CONFIG_FILE" | grep "^security_token_file" | head -1)
profile_fingerprint=$(grep -A10 "^\[$OCI_CONFIG_PROFILE\]" "$OCI_CLI_CONFIG_FILE" | grep "^fingerprint" | head -1)
profile_tenancy=$(grep -A10 "^\[$OCI_CONFIG_PROFILE\]" "$OCI_CLI_CONFIG_FILE" | grep "^tenancy" | head -1)

if [ -n "$profile_token" ] && [ -z "$profile_user" ]; then
    echo "⚠️  Profile $OCI_CONFIG_PROFILE uses session-based auth (security_token_file)"
    echo "   This is incompatible with Terraform. Switching to DEFAULT profile."
    export OCI_CONFIG_PROFILE="DEFAULT"
fi

# Check if the key file for this profile actually exists
if [ -n "$profile_key" ]; then
    key_path=$(echo "$profile_key" | cut -d'=' -f2 | tr -d ' ')
    if [ ! -f "$key_path" ]; then
        echo "❌ ERROR: Key file for profile $OCI_CONFIG_PROFILE not found: $key_path"
        echo ""
        echo "Available profiles with valid keys:"
        grep "^\[" "$OCI_CLI_CONFIG_FILE" | while read -r profile_line; do
            profile_name=$(echo "$profile_line" | tr -d '[]')
            profile_key_line=$(grep -A10 "^$profile_line" "$OCI_CLI_CONFIG_FILE" | grep "^key_file" | head -1)
            if [ -n "$profile_key_line" ]; then
                key_file=$(echo "$profile_key_line" | cut -d'=' -f2 | tr -d ' ')
                if [ -f "$key_file" ]; then
                    echo "  ✓ $profile_name - key exists"
                fi
            fi
        done
        echo ""
        echo "Please ensure the OCI API key is properly mounted in the container."
        echo "The key should be at: $key_path"
        exit 1
    fi
fi

# Verify all required fields are present
if [ -z "$profile_user" ] || [ -z "$profile_key" ] || [ -z "$profile_fingerprint" ] || [ -z "$profile_tenancy" ]; then
    echo "❌ ERROR: Profile $OCI_CONFIG_PROFILE is missing required fields"
    echo "  User: $profile_user"
    echo "  Key: $profile_key"
    echo "  Fingerprint: $profile_fingerprint"
    echo "  Tenancy: $profile_tenancy"
    exit 1
fi

echo ""

# Set the profile for Terraform
echo "Setting OCI profile for Terraform: $OCI_CONFIG_PROFILE"
export TF_VAR_config_file_profile="$OCI_CONFIG_PROFILE"

# CRITICAL: Terraform will use OCI_CLI_CONFIG_FILE environment variable
echo "Terraform will use config from: $OCI_CLI_CONFIG_FILE"

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

# Check if compartment_id is already set (from Semaphore Variable Group)
if [ -n "$compartment_id" ]; then
    echo "Using compartment_id from Semaphore Variable Group"
    export TF_VAR_compartment_id="$compartment_id"
elif [ -n "$TF_VAR_compartment_id" ]; then
    echo "Using existing TF_VAR_compartment_id"
elif [ -f terraform.tfvars ]; then
    echo "Using terraform.tfvars file"
else
    echo "⚠️  No compartment_id found in environment or terraform.tfvars"
    echo "   Using example compartment_id for demo purposes"
    export TF_VAR_compartment_id="ocid1.compartment.oc1..aaaaaaaaq3qy3dmnci7vbc6vdzwaptmz6m4u667exhuc2zem4pde4f4fulea"
fi

# Also export region if provided by Semaphore
if [ -n "$region" ]; then
    echo "Using region from Semaphore Variable Group: $region"
    export TF_VAR_region="$region"
fi

# Show what variables we're using
echo "Terraform variables:"
env | grep "TF_VAR_" || echo "No TF_VAR_ variables set"

terraform plan -input=false
echo ""
echo "✓ Plan complete"
echo ""

echo "================================================"
echo "Task completed successfully!"
echo "To apply: terraform apply -auto-approve"
echo "================================================"