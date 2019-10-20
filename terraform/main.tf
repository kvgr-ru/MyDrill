# ###########################################
# MAIN
###########################################

data "template_file" "ssh_key_user" {
  template = "${var.user_public_key}"
}

# Create user's ssh key
resource "vscale_ssh_key" "cloud_user" {
  name = "cloud_user's key"
  key  = "${data.template_file.ssh_key_user.rendered}"
}

# Build list of all groups of hosts
locals {
  hosts_groups = "${keys(var.hosts)}"
}

# Build list of all hosts
data "null_data_source" "hosts_list" {
  count = "${length(local.hosts_groups)}"

  inputs {
    hosts = "${join(",",var.hosts[local.hosts_groups[count.index]],)}"
  }
}

locals {
  hosts = "${split(",",join(",",data.null_data_source.hosts_list.*.outputs.hosts))}"
}

# Create a new scalet
resource "vscale_scalet" "vps" {
  count     = "${length(local.hosts)}"
  name      = "${local.hosts[count.index]}"
  ssh_keys  = ["${vscale_ssh_key.cloud_user.id}", "${vscale_ssh_key.kvgr.id}"]
  make_from = "${var.vscale_centos_7}"
  location  = "${var.vscale_msk}"
  rplan     = "${var.vscale_plan}"

  provisioner "remote-exec" {
    inline = [
      "hostnamectl set-hostname ${local.hosts[count.index]}.${var.domain}",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = "${file(var.user_private_key_path)}"
    }
  }
}

# Get aws zone
data "aws_route53_zone" "kvgr" {
  name = "${var.domain}."
}

# Create DNS records forall vps
resource "aws_route53_record" "vps" {
  count   = "${length(vscale_scalet.vps.*.name)}"
  zone_id = "${data.aws_route53_zone.kvgr.zone_id}"
  name    = "${element(vscale_scalet.vps.*.name, count.index )}.${var.domain}"
  type    = "A"
  ttl     = "300"
  records = ["${element(vscale_scalet.vps.*.public_address, count.index)}"]
}

locals {
  "proxies" = "${var.hosts[local.hosts_groups[index(local.hosts_groups,"proxy")]]}"
}

# Add www DNS records for proxies
resource "aws_route53_record" "vps_www" {
  count   = "${length(local.proxies)}"
  zone_id = "${data.aws_route53_zone.kvgr.zone_id}"
  name    = "www.${local.proxies[count.index]}.${var.domain}"
  type    = "A"

  alias {
    name                   = "${local.proxies[count.index]}.${var.domain}"
    zone_id                = "${data.aws_route53_zone.kvgr.zone_id}"
    evaluate_target_health = false
  }

  depends_on = ["aws_route53_record.vps"]
}

# Build ansible inventory file
data "null_data_source" "all_hosts" {
  count = "${length(local.hosts_groups)}"

  inputs = {
    hosts = "${join(",",formatlist("%s  ansible_host=%s.%s",var.hosts[local.hosts_groups[count.index]],var.hosts[local.hosts_groups[count.index]],"${var.domain}"))}"
  }
}

data "template_file" "inventory" {
  count    = "${length(local.hosts_groups)}"
  template = "${file("./ansible_inventory.tpl")}"

  vars {
    group = "${local.hosts_groups[count.index]}"
    hosts = "${join("\n",split(",",data.null_data_source.all_hosts.*.outputs.hosts[count.index]))}"
  }
}

# Save ansible inventory file
resource "local_file" "inventory" {
  content  = "${join("\n",data.template_file.inventory.*.rendered)}"
  filename = "../ansible/inventory"
}

# Template for configuration ansible keys
data "template_file" "aws_keys" {
  template = "${file("./ansible_aws_keys.tpl")}"

  vars {
    aws_access_key = "${var.aws_access_key}"
    aws_secret_key = "${var.aws_secret_key}"
  }
}

# Save ansible keys file
resource "local_file" "ansible_keys" {
  content  = "${data.template_file.aws_keys.rendered}"
  filename = "../ansible/roles/certbot/vars/aws_keys.yml"
}

# Template for configuration ansible nginx defaults
data "template_file" "ansible_all_vars" {
  template = "${file("./ansible_all_defaults.tpl")}"

  vars {
    user_private_key = "${var.user_private_key_path}"
    zone_name        = "${var.domain}."
    worker_proc      = "${var.worker_proc}"
    worker_conn      = "${var.worker_conn}"
    fw_ports         = "${join(", ", var.fw_ports)}"
  }
}

# Save ansible nginx default variables file
resource "local_file" "all_defaults" {
  content  = "${data.template_file.ansible_all_vars.rendered}"
  filename = "../ansible/group_vars/all"
}

# Write the new instance hosts keys to the known_hosts file
resource "null_resource" "known_hosts" {
  count = "${length(aws_route53_record.vps.*.name)}"

  provisioner "local-exec" {
    command = "ssh-keyscan '${element(aws_route53_record.vps.*.name, count.index)}' >> ~/.ssh/known_hosts"
  }
}

# Remove instance host key from the known_hosts file
resource "null_resource" "clear_known_hosts" {
  count = "${length(aws_route53_record.vps.*.name)}"

  provisioner "local-exec" {
    when = "destroy"

    command = <<EOT
      ssh-keygen -R '${element(aws_route53_record.vps.*.name, count.index)}';
      ssh-keygen -R '${element(vscale_scalet.vps.*.public_address, count.index)}'
    EOT
  }
}

# Run Ansible playbook
resource "null_resource" "ansible" {
  provisioner "local-exec" {
    command = "ansible-playbook -i ../ansible/inventory ../ansible/site.yml"
  }

  depends_on = ["vscale_scalet.vps", "local_file.inventory", "local_file.ansible_keys", "local_file.all_defaults", "null_resource.known_hosts"]
}
