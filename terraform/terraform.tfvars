user_private_key_path = "~/.ssh/do_rsa"

user_public_key = "${file("~/.ssh/do_rsa.pub")}"

hosts = {
    "proxy" = ["kvgr"]
    "web"   = ["kvgrweb"]
}
