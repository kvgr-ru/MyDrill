###########################################
# PROVIDERS
###########################################

# Configure the vscale Provider
provider "vscale" {
  token = "${var.VSCALE_API_TOKEN}"
}

# Configure the AWS Provider
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}
