resource "aws_security_group" "cmoradb19c_sg" {
  name        = "cmoradb19c-sg-${random_id.id.hex}"
  description = "Security Group for cmoradb19c"

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
    cidr_blocks = var.allowed_cidr_blocks
  }
  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "oracle19c" {
  ami                    = var.ami_oracle19c
  instance_type          = var.instance_type_resource
  key_name               = var.ssh_key_name
  vpc_security_group_ids = ["${aws_security_group.cmoradb19c_sg.id}"]
  user_data              = data.template_file.oracle_instanceDB.rendered
  
  root_block_device {
    volume_type = "gp3"
    volume_size = 1000
  }

  tags = {
    "Name"        = "oracle19c-${random_id.id.hex}",
    "owner_email" = var.owner_email
  }

  provisioner "local-exec" {
    command = "bash ./00_create_client.properties.sh ${aws_instance.oracle19c.public_ip}"
    when = create
  }
}

