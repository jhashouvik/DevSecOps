#------------------
# Create EC2 Server
#------------------
data "aws_vpc" "default" {
    default = true
}

data "aws_prefix_list" "ec2_instance_connect" {
    name = "com.amazonaws.ap-south-1.ec2-instance-connect"
}

resource "aws_security_group" "server" {
    name_prefix = "${var.servername}-"
    description = "Allow EC2 Instance Connect SSH access"
    vpc_id      = data.aws_vpc.default.id

    ingress {
        description     = "EC2 Instance Connect SSH"
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        prefix_list_ids = [data.aws_prefix_list.ec2_instance_connect.id]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "server" {
   ami           = var.amiid
   instance_type = var.type
   key_name      = var.pemfile
     vpc_security_group_ids = [aws_security_group.server.id]
  
   root_block_device {
       volume_size = var.volsize
   }
   associate_public_ip_address = true

   tags = {
        Name = "${var.servername} - WEZVATECH"
    }

}
