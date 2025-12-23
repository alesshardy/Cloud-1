terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.16"
        }
    }
    required_version = ">= 1.2.0"
}

#1 Region Stockholm car j'ai creer la key la bas la premiere fois
provider "aws" {
    region = "eu-west-3"
}

#2 Securite (firewall)
resource "aws_security_group" "cloud1_sg" {
    name        = "cloud1_security_group"
    description = "Allow SSH, HTTP, HTTPS"

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # SSH
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # HTTPS
    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#3 Recherche image Ubuntu 22.04 
data "aws_ami" "ubuntu" {
    most_recent = true
    owners      = ["099720109477"] #Canonical

    filter {
        name    = "name"
        values  = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

#4 Creation server
resource "aws_instance" "web_server" {
    ami         = data.aws_ami.ubuntu.id

    instance_type = "t3.micro"

    key_name      = "cloud1-paris"

    vpc_security_group_ids = [aws_security_group.cloud1_sg.id]

    tags = {
        Name = "Cloud-1-Terraform"
    }
}

#4 Affiche l'IP
output "server_ip" {
    value = aws_instance.web_server.public_ip
}