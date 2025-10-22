resource "aws_security_group" "cdcworkshop_oracle26ai-sg" {
  name        = "cdcworkshop_oracle26ai-sg-${random_id.id.hex}"
  description = "Security Group for cdc workshop abd oracle 26ai "

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.myip]
  }
  # DB
  ingress {
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#"${data.aws_ami.ami.id}"

resource "aws_instance" "cdcworkshop_oracle26ai" {
  ami                    = "ami-0c1b03e30bca3b373" # Amazon Linux 2023 kernel-6.12 AMI
  #ami                    = "${data.aws_ami.ami.id}"
  instance_type          = var.instance_type_resource
  key_name               = var.ssh_key_name
  vpc_security_group_ids = ["${aws_security_group.cdcworkshop_oracle26ai-sg.id}"]
  user_data              = data.template_file.oracle_instance.rendered
  
  root_block_device {
    volume_type = "gp2"
    volume_size = 100
  }

  tags = {
    "Name"        = "cdcworkshop-oracle26ai-${random_id.id.hex}",
    "owner_email" = var.owner_email
  }

#  provisioner "local-exec" {
#    command = "bash ./00_create_client.properties.sh ${aws_instance.cdcworkshop_oracle26ai.public_ip}"
#    when = create
#  }
}
