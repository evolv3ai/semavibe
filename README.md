# OCI Two Free Servers (Terraform + Ansible)

This repo provisions **two Always-Free** Oracle Cloud instances with Terraform, then configures them with Ansible.

## Prereqs
- OCI API key configured in `~/.oci/config` (profile `DEFAULT`).
- SSH keypair for VM logins (default: `~/.ssh/id_ed25519_oci(.pub)`).

## Structure
- `infra/terraform/` — VCN, subnet, security list, 2× instances
- `ansible/` — simple post-provision config (example)
- Scripts:
  - `make_inventory.sh` — builds an Ansible inventory from Terraform outputs
  - `run_ansible.sh` — runs the Ansible playbook using the generated inventory

## Quickstart (local)
```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# edit region/compartment/AD and ssh_public_key_path
terraform init -input=false
terraform apply -auto-approve

# Build inventory and run Ansible
./make_inventory.sh
./run_ansible.sh

# Tear down
terraform destroy -auto-approve
```

## In Semaphore

* Template 1 (Terraform): working dir `infra/terraform`, command:

  ```
  terraform init -input=false && terraform apply -auto-approve
  ```
* Template 2 (Ansible): working dir `infra/terraform`, command:

  ```
  ./make_inventory.sh && ./run_ansible.sh
  ```

