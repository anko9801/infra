output "instances" {
  value = {
    for name, instance in oci_core_instance.nodes : name => {
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  }
}

output "ssh_config" {
  value = <<-EOT
# Add to ~/.ssh/config
%{ for name, instance in oci_core_instance.nodes ~}
Host ${name}
  HostName ${instance.public_ip}
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519

%{ endfor ~}
EOT
}
