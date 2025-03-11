###########################################
################# Outputs #################
###########################################


output "A00_instance_details" {
  description = "oracleDB compute detaisl"
  value       = aws_instance.oracle21c
}

output "A01_PUBLICIP" {
  description = "oracleDB Public IP"
  value       = aws_instance.oracle21c.public_ip
}

output "A02_ORACLESERVERNAME" {
  description = "oracleDB Servername"
  value       = aws_instance.oracle21c.public_ip
}

output "A03_SSH" {
  description = "SSH Access"
  value       = "SSH  Access: ssh -i ~/keys/${join(",", formatlist("%s", var.ssh_key_name), )}.pem ec2-user@${join(",", formatlist("%s", aws_instance.oracle21c.public_ip), )} "
}

output "A04_OracleAccess" {
  value = "sqlplus sys/confluent123@XE as sysdba or sqlplus sys/confluent123@XEPDB1 as sysdba or sqlplus ordermgmt/kafka@XEPDB1  c##ggadmin/Confluent12!@XE Port:1521  HOST:${aws_instance.oracle21c.public_ip}"
}

