#configure AWS provider
provider "aws" {
  region = "ap-southeast-1"
  access_key = ""
  secret_key = ""
  }

#Create VPC  
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Production VPC"
  }
} 

#Create internet gateway
resource "aws_internet_gateway" "prod-internet-gateway" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "Production Internet Gateway"
  }
}

#create a route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-internet-gateway.id 
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prod-internet-gateway.id 
  }

  tags = {
    Name = "Production Route Table"
  }
}

#Create a subnet
resource "aws_subnet" "prod-subnet" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "Production Subnet"
  }
}

#Create route table association
resource "aws_route_table_association" "prod-route-table-assoication" {
  subnet_id      = aws_subnet.prod-subnet.id
  route_table_id = aws_route_table.prod-route-table.id 
}

#Create security group
resource "aws_security_group" "prod-security-group" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "production Security Group"
  }
}

#Create network interface
resource "aws_network_interface" "prod-network-interface" {
  subnet_id       = aws_subnet.prod-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.prod-security-group.id]

  tags = {
    Name = "production Network Interface"
  }

}

resource "aws_eip" "prod-elastic-ip" {
  vpc                       = true
  network_interface         = aws_network_interface.prod-network-interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.prod-internet-gateway
  ]

  tags = {
    Name = "Production Elastic IP"
  }
}

#Create ubuntu server
resource "aws_instance" "prod-web-server" {
  ami           = "ami-01581ffba3821cdf3"
  instance_type = "t2.micro"
  availability_zone = "ap-southeast-1a"
  key_name = "main-key"

  network_interface {
    device_index =0 
     network_interface_id = aws_network_interface.prod-network-interface.id 
  }

  user_data = <<-EOF
               #!/bin/bash
               sudo apt update -y
               sudo apt  install apache2 -y
               sudo systemctl start apache2
               sudo systemctl enable apache2
               sudo bash -c "echo your very first web server" > /var/www/html/index.html

    EOF
   
  tags = {
    Name = "Production Web Server"
  }
}