#!/usr/bin/env bash
set -euo pipefail
# Generates a temp inventory file from Terraform outputs
# Writes to /tmp/inventory.<pid>
inv="/tmp/inventory.$$"
ips=$(terraform output -json instance_public_ips | jq -r '.[]')

: > "$inv"
for ip in $ips; do
  echo "$ip" >> "$inv"
done

echo "$inv"
