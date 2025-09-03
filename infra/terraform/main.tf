terraform {
  required_version = ">= 1.4.0"
  required_providers {
    oci = { source = "oracle/oci" }
  }
}

provider "oci" {
  # Reads from ~/.oci/config on the runner (mounted into Semaphore container)
  config_file_profile = var.oci_profile
  region              = var.region
}

# --- Networking ---
resource "oci_core_vcn" "vcn" {
  cidr_block     = var.vcn_cidr
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-vcn"
  dns_label      = lower(replace(substr(var.name_prefix,0,11), "/[^a-zA-Z0-9]/", ""))
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.name_prefix}-igw"
  enabled        = true
}

resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.name_prefix}-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_security_list" "sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.name_prefix}-sl"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options { min = 22, max = 22 } # SSH
  }
}

resource "oci_core_subnet" "subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn.id
  cidr_block                 = var.subnet_cidr
  display_name               = "${var.name_prefix}-subnet"
  dns_label                  = lower(replace(substr("${var.name_prefix}sub",0,15), "/[^a-zA-Z0-9]/", ""))
  route_table_id             = oci_core_route_table.rt.id
  security_list_ids          = [oci_core_security_list.sl.id]
  prohibit_public_ip_on_vnic = false
}

# --- Image lookup (latest Oracle Linux) ---
data "oci_core_images" "ol" {
  compartment_id   = var.compartment_ocid
  operating_system = "Oracle Linux"
  sort_by          = "TIMECREATED"
  sort_order       = "DESC"
}

locals {
  image_id = length(data.oci_core_images.ol.images) > 0 ? data.oci_core_images.ol.images[0].id : null
}

# --- Two Always-Free compatible instances ---
resource "oci_core_instance" "vm" {
  count               = 2
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "${var.name_prefix}-vm-${count.index + 1}"
  shape               = var.shape

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.subnet.id
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  preserve_boot_volume = false
}
