###############################################################################
# 選択肢B: DBをパブリックサブネットに配置 + プライベートサブネットのルートテーブルにNAT GW
#
# 問題点:
#   - DBがパブリックサブネットにいるのでパブリックIPが付与される
#   - IGWを通じてインターネットから直接到達可能
#   - プライベートサブネットにNATルートを設定しても、DBはパブリックにいるので無関係
#   - → インバウンド遮断の要件を満たさない（不正解）
###############################################################################

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "ap-northeast-1"
}
variable "project_name" {
  default = "saa-q07-b"
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# --- パブリックサブネット（DBをここに配置） ---
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public" }
}

# --- プライベートサブネット ---
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = { Name = "${var.project_name}-private" }
}

# --- パブリックサブネットのルートテーブル（IGW） ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- NAT Gateway（パブリックサブネットに配置） ---
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = { Name = "${var.project_name}-nat" }

  depends_on = [aws_internet_gateway.igw]
}

# --- プライベートサブネットのルートテーブル（NAT GW = 選択肢Bの設定） ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# --- セキュリティグループ（DB用） ---
resource "aws_security_group" "db" {
  name_prefix = "${var.project_name}-db-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
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

  tags = { Name = "${var.project_name}-db-sg" }
}

# --- AMI ---
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# --- DB用 EC2 インスタンス（パブリックサブネットに配置） ---
resource "aws_instance" "db" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.db.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y mariadb105-server
    systemctl start mariadb
    systemctl enable mariadb
  EOF

  tags = { Name = "${var.project_name}-db-instance" }
}

# --- Outputs ---
output "db_public_ip" {
  description = "DB instance public IP"
  value       = aws_instance.db.public_ip
}

output "db_private_ip" {
  description = "DB instance private IP"
  value       = aws_instance.db.private_ip
}

output "nat_gateway_ip" {
  description = "NAT Gateway public IP（プライベートサブネット用だがDBはパブリックにいる）"
  value       = aws_eip.nat.public_ip
}

output "verdict" {
  value = <<-EOT

    ============================================================
    選択肢B: パブリックサブネット + プライベートRTにNAT GW
    ============================================================
    DBサーバーはパブリックサブネットに配置されています。
    → パブリックIPが付与されている: ${aws_instance.db.public_ip}
    → インターネットから直接到達可能（要件違反）

    プライベートサブネットにNATルートを設定していますが、
    DBはパブリックサブネットにいるので全く意味がありません。
    NATゲートウェイの費用が無駄にかかるだけです。

    結果: ❌ 不正解（DBがパブリックサブネットにいる時点でアウト）
    ============================================================
  EOT
}
