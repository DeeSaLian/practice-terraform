provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA6GBMC3D7B4Y3IGO4"
  secret_key = "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"
}

#variable "subnet_prefic" {
#    description = "cidr block for the subnet"
#}

# Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# Create custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# Create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Prod-subnet"
  }
}

# Associate subnet with the route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create a security group to allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow-web-traffic"
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
    description = "HTTP"
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
    Name = "allow_tls"
  }
}

# Create network Interface for web server with IP 10.0.1.50
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Create AWS elastic IP for web server
resource "aws_eip" "web_server_eip" {
  instance                  = aws_instance.my-web-server-instance.id
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

output "server_public_ip" {
  value = aws_eip.web_server_eip.public_ip
}

# Create Ubuntu server and install apache2
resource "aws_instance" "my-web-server-instance" {
  ami               = "ami-0c7217cdde317cfec"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "deedevopsvm"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF

  tags = {
    Name = "Apache"
  }
}

# Create network Interface for nginx server with IP 10.0.1.51
resource "aws_network_interface" "web-server-nic-nginx" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.51"]
  security_groups = [aws_security_group.allow_web.id]
}

# Create AWS elastic IP for nginx-server and associate it with the correct network interface
resource "aws_eip" "nginx_server_eip" {
  instance                  = aws_instance.nginx-server.id
  network_interface         = aws_network_interface.web-server-nic-nginx.id
  associate_with_private_ip = "10.0.1.51"
  depends_on                = [aws_internet_gateway.gw]
}

# Create the nginx server instance
resource "aws_instance" "nginx-server" {
  ami               = "ami-0c7217cdde317cfec"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "deedevopsvm"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic-nginx.id
  }

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install nginx -y
              echo "<h1>Hello World from Nginx!</h1>" > /var/www/html/index.html
              service nginx start
              EOF

  tags = {
    Name = "Nginx-Server"
  }
}

output "server_private_ip" {
  value = aws_instance.nginx-server.private_ip
}

output "server_id" {
  value = aws_instance.nginx-server.id
}




