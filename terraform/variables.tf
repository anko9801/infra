variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "private_key_password" {
  default   = ""
  sensitive = true
}
variable "compartment_ocid" {}

variable "region" {
  default = "ap-tokyo-1"
}

variable "ssh_public_key_path" {
  default = "~/.ssh/id_ed25519.pub"
}

variable "vcn_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  default = "10.0.0.0/24"
}

variable "instances" {
  type = map(object({
    ocpus     = number
    memory_gb = number
    role      = string
  }))
  default = {
    pikachu = { ocpus = 1, memory_gb = 6, role = "cp" }
    metamon = { ocpus = 1, memory_gb = 6, role = "worker" }
    bracky  = { ocpus = 1, memory_gb = 6, role = "worker" }
    pochama = { ocpus = 1, memory_gb = 6, role = "infra" }
  }
}
