###############################################################################
# 選択肢C: DBをプライベートサブネットに配置 + ルートテーブルにIGWへのルート
#
# 問題点:
#   - DBはプライベートサブネットにいるのでパブリックIPは付かない
#   - しかしIGWはパブリックIPを持つインスタンスしかNATしない
#   - プライベートIPのみのインスタンスはIGW経由でインターネットに出られない
#   - → アウトバウンド（パッチDL）の要件を満たさない（不正解）
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
  default = "saa-q07-c"
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

# --- パブリックサブネット（踏み台用） ---
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public" }
}

# --- プライベートサブネット（DBをここに配置） ---
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = { Name = "${var.project_name}-private" }
}

# --- パブリックサブネットのルートテーブル ---
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

# --- プライベートサブネットのルートテーブル（IGW = 選択肢Cの設定） ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# --- セキュリティグループ（踏み台用） ---
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-bastion-"
  vpc_id      = aws_vpc.main.id

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

  tags = { Name = "${var.project_name}-bastion-sg" }
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
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
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

# --- 踏み台 EC2 ---
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  tags = { Name = "${var.project_name}-bastion" }
}

# --- DB用 EC2 インスタンス（プライベートサブネットに配置） ---
resource "aws_instance" "db" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.db.id]
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y mariadb105-server
    systemctl start mariadb
    systemctl enable mariadb
  EOF

  tags = { Name = "${var.project_name}-db-instance" }
}

# --- Outputs ---
output "bastion_public_ip" {
  description = "Bastion public IP (SSH経由でDBに接続)"
  value       = aws_instance.bastion.public_ip
}

output "db_private_ip" {
  description = "DB instance private IP"
  value       = aws_instance.db.private_ip
}

output "db_public_ip" {
  description = "DB instance public IP (プライベートサブネットなので空)"
  value       = aws_instance.db.public_ip
}

output "verdict" {
  value = <<-EOT

    ============================================================
    選択肢C: プライベートサブネット + プライベートRTにIGW
    ============================================================
    DBサーバーはプライベートサブネットに配置されています。
    → パブリックIPなし → インターネットから直接アクセス不可 ✅

    しかし、ルートテーブルにIGWへのルートを設定しています。
    IGWはパブリックIPを持つインスタンスにしかNATを行いません。
    → プライベートIPのみのDBはIGW経由でインターネットに出られない
    → パッチのダウンロードができない ❌

    検証: 踏み台経由でDBにSSHし、curl を実行してみてください
      ssh -J ec2-user@${aws_instance.bastion.public_ip} ec2-user@${aws_instance.db.private_ip}
      curl -m 5 https://example.com  # → タイムアウトする

    結果: ❌ 不正解（アウトバウンド通信ができない）
    ============================================================
  EOT
}
