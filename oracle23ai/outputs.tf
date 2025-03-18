###########################################
################# Outputs #################
###########################################


output "A00_instance_details" {
  description = "oracleDB compute details"
  value       = aws_instance.cdcworkshop_oracle23ai
}

output "A01_PUBLICIP" {
  description = "oracleDB Public IP"
  value       = aws_instance.cdcworkshop_oracle23ai.public_ip
}

output "A02_ORACLESERVERNAME" {
  description = "oracleDB Servername"
  value       = aws_instance.cdcworkshop_oracle23ai.public_ip
}

output "A03_SSH" {
  description = "SSH Access"
  value       = "SSH  Access: ssh -i  ~/keys/cmawsdemoxstream.pem ec2-user@${join(",", formatlist("%s", aws_instance.cdcworkshop_oracle23ai.public_ip), )} "
}

output "A04_OracleAccess" {
  value = "sqlplus sys/confluent123@FREE as sysdba or sqlplus sys/confluent123@FREEPDB1 as sysdba or sqlplus ordermgmt/kafka@FREEPDB1  Port:1521  HOST:${aws_instance.cdcworkshop_oracle23ai.public_ip}"
}

