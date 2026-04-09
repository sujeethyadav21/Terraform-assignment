terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "my-terraform-state-bucket"   # <-- replace with your S3 bucket
    key    = "part2/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────
# VPC & Networking
# ─────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "part2-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "part2-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "part2-public-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "part2-public-rt" }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# ─────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────
resource "aws_security_group" "flask_sg" {
  name        = "part2-flask-sg"
  description = "Flask backend security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow Express instance to reach Flask on port 5000
  ingress {
    description     = "Flask from Express SG"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.express_sg.id]
  }

  # Public access to Flask
  ingress {
    description = "Flask public"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "part2-flask-sg" }
}

resource "aws_security_group" "express_sg" {
  name        = "part2-express-sg"
  description = "Express frontend security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Express public"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "part2-express-sg" }
}

# ─────────────────────────────────────────
# Flask EC2 Instance
# ─────────────────────────────────────────
resource "aws_instance" "flask_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.flask_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y python3 python3-pip

    mkdir -p /opt/flask-app
    cat > /opt/flask-app/app.py <<'PYEOF'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({"message": "Flask Backend Running!", "status": "healthy"})

@app.route('/health')
def health():
    return jsonify({"status": "ok"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYEOF

    pip3 install flask gunicorn

    cat > /etc/systemd/system/flask.service <<'SVCEOF'
[Unit]
Description=Flask Backend
After=network.target

[Service]
WorkingDirectory=/opt/flask-app
ExecStart=/usr/local/bin/gunicorn --bind 0.0.0.0:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable flask
    systemctl start flask
  EOF

  tags = { Name = "part2-flask-server" }
}

# ─────────────────────────────────────────
# Express EC2 Instance
# ─────────────────────────────────────────
resource "aws_instance" "express_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.express_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y nodejs npm

    mkdir -p /opt/express-app
    cat > /opt/express-app/index.js <<'JSEOF'
const express = require('express');
const app = express();
const PORT = 3000;
const FLASK_URL = process.env.FLASK_URL || 'http://localhost:5000';

app.get('/', (req, res) => {
  res.json({ message: 'Express Frontend Running!', flask_backend: FLASK_URL });
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.listen(PORT, '0.0.0.0', () => console.log(`Express on port ${PORT}`));
JSEOF

    cat > /opt/express-app/package.json <<'PKGEOF'
{"name":"express-app","version":"1.0.0","dependencies":{"express":"^4.18.2"}}
PKGEOF

    cd /opt/express-app && npm install

    cat > /etc/systemd/system/express.service <<'SVCEOF'
[Unit]
Description=Express Frontend
After=network.target

[Service]
WorkingDirectory=/opt/express-app
Environment=FLASK_URL=http://${aws_instance.flask_server.private_ip}:5000
ExecStart=/usr/bin/node index.js
Restart=always

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable express
    systemctl start express
  EOF

  tags = { Name = "part2-express-server" }

  depends_on = [aws_instance.flask_server]
}
