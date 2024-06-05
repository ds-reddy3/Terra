provider "aws" {
  region = "us-east-1"
}
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/24"
  instance_tenancy = "default"

  tags = {
    Name = "VPC-main"
  }
}
resource "aws_subnet" "pub-subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/26"

  tags = {
    Name = "Public-subnet"
  }
}

resource "aws_subnet" "pri-subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.64/26"

  tags = {
    Name = "Private-subnet"
  }
}
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "IGW"
  }
}
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  tags = {
    Name = "RT"
  }
}
resource "aws_route_table_association" "RT1" {
  subnet_id      = aws_subnet.pub-subnet.id
  route_table_id = aws_route_table.RT.id
}
resource "aws_security_group" "SG" {
  vpc_id = aws_vpc.main.id
  # Inbound Rules
  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Outbound Rules
  # Internet access to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Create Security Group"
  }
}
resource "aws_instance" "ubuntu" {
  ami                         = "ami-04b70fa74e45c3917"
  instance_type               = "t2.micro"
  key_name                    = "terraform"
  security_groups             = [aws_security_group.SG.id]
  subnet_id                   = aws_subnet.pub-subnet.id
  associate_public_ip_address = true
  user_data                   = <<-EOF
                  #!/bin/bash
                  apt update -y
                  apt install -y apache2
                  systemctl start apache2
                  systemctl enable apache2
                  EOF
  tags = {
    Name = "Ubuntu-server"
  }
}
resource "aws_network_interface" "network" {
  subnet_id       = aws_subnet.pub-subnet.id
  private_ips     = ["10.0.0.33"]
  security_groups = [aws_security_group.SG.id]

  attachment {
    instance     = aws_instance.ubuntu.id
    device_index = 1
  }
}
resource "aws_eip" "Elastic" {
  domain = "vpc" # specify vpc for a vpc-owned elastic ip
}

resource "aws_eip_association" "Elastic" {
  network_interface_id = aws_network_interface.network.id
  allocation_id        = aws_eip.Elastic.id
}
resource "aws_s3_bucket" "s3_bucket" {

    bucket = "srinu153"
    acl = "private"
}
resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name = "terraform-state-lock-dynamo"
  hash_key = "LockID"
  read_capacity = 20
  write_capacity = 20

  attribute {
    name = "LockID"
    type = "S"
  }
}
terraform {
  backend "s3" {
    bucket = "srinu153"
    dynamodb_table = "terraform-state-lock-dynamo"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}