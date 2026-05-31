terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. Fetch the latest Amazon Linux 2023 AMI ID
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 2. Create the Security Group with descriptive rules
resource "aws_security_group" "k8s_sg" {
  name        = "kubernetes-nodes-sg"
  description = "Security group for Kubernetes nodes with specific port mappings"

  # SSH Access
  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change to your IP for better security
  }

  # Kubernetes API Server
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubelet API, kube-scheduler, and kube-controller-manager
  ingress {
    description = "Kubelet API, Scheduler, and Controller Manager"
    from_port   = 10250
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort Services
  ingress {
    description = "Kubernetes NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules (Allow all traffic)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-security-group"
  }
}

# 3. Provision the EC2 Instance
resource "aws_instance" "k8s_node" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.large"
  key_name      = "ltim" # Your existing key in us-east-1

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  root_block_device {
    volume_size           = 80
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "k8s-amazon-linux-node"
  }
}

# 4. Output the public IP to access it easily
output "instance_public_ip" {
  value       = aws_instance.k8s_node.public_ip
  description = "The public IP of the newly created EC2 instance"
}