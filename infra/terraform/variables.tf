variable "oci_profile" {
  type    = string
  default = "DEFAULT"
}

variable "region" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "availability_domain" {
  type = string
  # e.g. "Uocm:US-ASHBURN-AD-1"
}

variable "name_prefix" {
  type    = string
  default = "afree"
}

variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519_oci.pub"
}

# Always Free x86: VM.Standard.E2.1.Micro ; ARM: VM.Standard.A1.Flex (with OCPUs/RAM)
variable "shape" {
  type    = string
  default = "VM.Standard.E2.1.Micro"
}
