output "instance_public_ips" {
  value = [for i in oci_core_instance.vm : i.public_ip]
}

output "instance_ocids" {
  value = [for i in oci_core_instance.vm : i.id]
}

output "subnet_id" { value = oci_core_subnet.subnet.id }
output "vcn_id"    { value = oci_core_vcn.vcn.id }
