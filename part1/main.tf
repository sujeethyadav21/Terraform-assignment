terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend for state management (General Requirement)
  backend "s3" {
    bucket = "my-terraform-state-bucket"   # <-- replace with your S3 bucket name
    key    = "part1/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────
# Security Group
# ─────────────────────────────────────────
resource "aws_security_group" "app_sg" {
  name        = "part1-app-sg"
  description = "Allow Flask (5000), Express (3000) and SSH (22)"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask backend"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Express frontend"
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

  tags = {
    Name = "part1-app-sg"
  }
}

# ─────────────────────────────────────────
# EC2 Instance
# ─────────────────────────────────────────
resource "aws_instance" "app_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # Cloud-Init user data installs Python & Node, then starts both apps
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # ── Update & install dependencies ──────────────────────────────
    apt-get update -y
    apt-get install -y python3 python3-pip nodejs npm git

    # ── Flask backend ───────────────────────────────────────────────
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

    # Run Flask as a systemd service
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

    # ── Express frontend ────────────────────────────────────────────
    mkdir -p /opt/express-app
    cat > /opt/express-app/index.js <<'JSEOF'
const express = require('express');
const app = express();
const PORT = 3000;

app.get('/', (req, res) => {
  res.json({ message: 'Express Frontend Running!', status: 'healthy' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Express running on port ${PORT}`);
});
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
ExecStart=/usr/bin/node index.js
Restart=always

[Install]
WantedBy=multi-user.target
SVCEOF

    # ── Enable & start services ─────────────────────────────────────
    systemctl daemon-reload
    systemctl enable flask express
    systemctl start flask express
  EOF

  tags = {
    Name = "part1-flask-express-server"
  }
}
