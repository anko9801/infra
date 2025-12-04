# Availability Domain
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Ubuntu 24.04 ARM Image
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# VCN
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "k8s-vcn"
  dns_label      = "k8svcn"
}

# Internet Gateway
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "k8s-igw"
  enabled        = true
}

# Route Table
resource "oci_core_route_table" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "k8s-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

# Security List
resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "k8s-sl"

  # Egress: 全許可
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Ingress: SSH
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress: HTTP
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # Ingress: HTTPS
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress: k8s API
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # Ingress: NodePort
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 30000
      max = 32767
    }
  }

  # Ingress: VCN内通信（全許可）
  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr
  }

  # Ingress: ICMP
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = var.vcn_cidr
    icmp_options {
      type = 3
    }
  }
}

# Subnet
resource "oci_core_subnet" "main" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.subnet_cidr
  display_name               = "k8s-subnet"
  dns_label                  = "k8ssub"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.main.id
  security_list_ids          = [oci_core_security_list.main.id]
}

# Compute Instances
resource "oci_core_instance" "nodes" {
  for_each = var.instances

  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = each.key
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.main.id
    assign_public_ip          = true
    display_name              = each.key
    assign_private_dns_record = true
    hostname_label            = each.key
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  freeform_tags = {
    role = each.value.role
  }
}
