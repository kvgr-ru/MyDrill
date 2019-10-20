# Ansible credentials
ansible_user: root
ansible_ssh_private_key_file: "${user_private_key}"

# This is used for the nginx server configuration
zone: "${zone_name}"
hosts_proxy: "{{ groups.proxy }}"
nginx_conf:
  worker_proc: "${worker_proc}"
  worker_conn: "${worker_conn}"
nginx_fw_ports: [${fw_ports}]
