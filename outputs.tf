output "kong_public_address" {
  value = "${aws_eip.kong.public_ip}"
}

output "master_public_address" {
  value = "${aws_instance.master.public_ip}"
}