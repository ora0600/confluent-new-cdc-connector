###########################################
################# Outputs #################
###########################################


output "A00_DBinstance_details" {
  description = "oracleDB compute details"
  value       = aws_instance.oracle19c
}



output "A01_DBPUBLICIP" {
  description = "oracleDB Public IP"
  value       = aws_instance.oracle19c.public_ip
}

output "A02_DBORACLESERVERNAME" {
  description = "oracleDB Servername"
  value       = aws_instance.oracle19c.public_dns
}

output "A03_DBSSH" {
  description = "SSH Access to oracleDB"
  value       = "SSH  Access: ssh -i ~/keys/${join(",", formatlist("%s", var.ssh_key_name), )}.pem ec2-user@${join(",", formatlist("%s", aws_instance.oracle19c.public_ip), )} "
}

output "A04_DBOracleAccess" {
  value = "sqlplus sys/confluent123@orcl as sysdba or sqlplus sys/confluent123@ORCLPDB1 as sysdba or sqlplus ordermgmt/kafka@ORCLPDB1 sqlplus c##ggadmin/Confluent12!@ORCLCDB Port:1521  HOST:${aws_instance.oracle19c.public_ip}"
}
