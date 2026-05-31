/*terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}*/

# Variable to control how many worker nodes you want to spin up
variable "worker_count" {
  default     = 2
  description = "Number of Kubernetes worker nodes to create"
  type        = number
}

/*# 1. Fetch the latest Amazon Linux 2023 AMI ID
data "aws_ami_worker" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}*/

# 2. Create a dedicated Security Group for Worker Nodes
resource "aws_security_group" "k8s_worker_sg" {
  name        = "kubernetes-worker-nodes-sg"
  description = "Security group for Kubernetes worker nodes"

  # SSH Access
  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP for production
  }

  # Kubelet API (Required by Master node to control the worker)
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Kube-Proxy Health Check 
  ingress {
    description = "Kube-Proxy Health Check"
    from_port   = 10256
    to_port     = 10256
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort Services (Where your actual applications will be exposed)
  ingress {
    description = "Kubernetes NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules (Allow all traffic so nodes can fetch container images, updates, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-worker-security-group"
  }
}

# 3. Provision the Worker Node Instance(s)
resource "aws_instance" "k8s_worker" {
  count         = var.worker_count
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.large"
  key_name      = "ltim" # Using your existing key

  vpc_security_group_ids = [aws_security_group.k8s_worker_sg.id]

  root_block_device {
    volume_size           = 80 # Matches your Master storage setup
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "k8s-worker-node-${count.index + 1}"
  }
}

# 4. Output the public IPs of all created workers
output "worker_public_ips" {
  value       = aws_instance.k8s_worker[*].public_ip
  description = "The public IPs of the newly created Kubernetes worker nodes"
}
