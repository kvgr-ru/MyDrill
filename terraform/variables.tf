###########################################
# VARIABLES
###########################################

###########################################
# keys
###########################################

variable "user_private_key_path" {}

variable "user_public_key" {}

###########################################
# vscale
###########################################

# vscale token
variable "VSCALE_API_TOKEN" {}

# Default vscale OS
variable "vscale_centos_7" {
  description = "Centos 7"
  default     = "centos_7_64_001_master"
}

# Default vscale region
variable "vscale_msk" {
  description = "vscale MSK data"
  default     = "msk0"
}

# Default vscale plan
variable "vscale_plan" {
  default = "medium"
}

# dns record prefix
variable "hosts" {
  type = "map"
}

###########################################
# Amazon
###########################################

# Amazon Web Services Token
variable "aws_access_key" {}

variable "aws_secret_key" {}

# Default aws region
variable "aws_region" {
  default = "eu-north-1"
}

# dns domain
variable "domain" {
  default = "devops.srwx.net"
}

###########################################
# Ansible
###########################################

variable "fw_ports" {
  type = "list"
}

variable "worker_proc" {}

variable "worker_conn" {}
