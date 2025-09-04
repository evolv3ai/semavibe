variable "compartment_id" {
  description = "OCID from your tenancy page"
  type        = string
}
variable "region" {
  description = "region where you have OCI tenancy"
  type        = string
  default     = "us-ashburn-1"
}
variable "config_file_profile" {
  description = "OCI config profile to use"
  type        = string
  default     = "DEFAULT"
}
