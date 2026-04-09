# AWS + Terraform Deployment Assignment

Deploy a Flask backend and Express frontend across three architectures using AWS and Terraform.

---

## Repository Structure

```
assignment/
├── apps/
│   ├── flask/
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── express/
│       ├── index.js
│       ├── package.json
│       └── Dockerfile
├── part1/          # Single EC2 Instance
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── part2/          # Two Separate EC2 Instances
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── part3/          # Docker + ECR + ECS + ALB
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── README.md
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configured (`aws configure`)
- [Docker](https://www.docker.com/) (Part 3 only)
- An existing EC2 Key Pair (Parts 1 & 2)
- An S3 bucket for Terraform remote state

---

## General Requirements

- All configs use `variables.tf` and `outputs.tf`
- Terraform state stored in **S3 backend** for remote state management
- Run `terraform plan` to preview, `terraform apply` to deploy

---

## Part 1 — Flask + Express on a Single EC2 Instance

### Architecture
Both applications run as **systemd services** on one EC2 instance:
- Flask backend → port **5000**
- Express frontend → port **3000**

### Steps

```bash
cd part1

# 1. Edit variables.tf — set your key_name and bucket name in main.tf
# 2. Initialize Terraform
terraform init

# 3. Preview changes
terraform plan

# 4. Deploy
terraform apply

# 5. Get the public IP from outputs
terraform output instance_public_ip
```

### Verify
```bash
curl http://<public-ip>:5000        # Flask
curl http://<public-ip>:3000        # Express
```

### Destroy
```bash
terraform destroy
```

---

## Part 2 — Flask + Express on Separate EC2 Instances

### Architecture
- Dedicated EC2 instance for Flask (port 5000)
- Dedicated EC2 instance for Express (port 3000)
- Custom **VPC** with public subnet, internet gateway, and route table
- Security groups allow inter-instance communication and public access

### Steps

```bash
cd part2

# 1. Edit variables.tf — set your key_name and bucket name in main.tf
terraform init
terraform plan
terraform apply

# 2. Get outputs
terraform output flask_url
terraform output express_url
```

### Networking Details
| Resource | Value |
|---|---|
| VPC CIDR | 10.0.0.0/16 |
| Public Subnet | 10.0.1.0/24 |
| Flask port | 5000 |
| Express port | 3000 |

### Verify
```bash
curl http://<flask-ip>:5000
curl http://<express-ip>:3000
```

---

## Part 3 — Docker + ECR + ECS + ALB

### Architecture
```
Internet → ALB (port 80 → Express, port 8080 → Flask)
           ↓
       ECS Cluster (Fargate)
       ├── express-service  (container port 3000)
       └── flask-service    (container port 5000)
           ↓
       ECR Repositories
       ├── flask-backend
       └── express-frontend
```

### Step 1 — Build & Push Docker Images to ECR

```bash
# Set your variables
ACCOUNT_ID=123456789012   # your AWS account ID
REGION=us-east-1

# Authenticate Docker to ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build & push Flask image
cd apps/flask
docker build -t flask-backend .
docker tag flask-backend:latest \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/flask-backend:latest
docker push \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/flask-backend:latest

# Build & push Express image
cd ../express
docker build -t express-frontend .
docker tag express-frontend:latest \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/express-frontend:latest
docker push \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/express-frontend:latest
```

> **Note:** Run `terraform apply` in part3/ first to create the ECR repos, then push images.

### Step 2 — Deploy Infrastructure

```bash
cd part3

# 1. Edit variables.tf — set your aws_account_id
# 2. Edit main.tf — set your S3 bucket name

terraform init
terraform plan
terraform apply
```

### Step 3 — Verify

```bash
# Get ALB DNS name
terraform output alb_dns_name

# Test endpoints
curl http://<alb-dns>        # Express frontend
curl http://<alb-dns>:8080   # Flask backend
```

### Resources Created
| Resource | Purpose |
|---|---|
| ECR (×2) | Store Flask & Express Docker images |
| VPC + 2 subnets | Isolated network across 2 AZs |
| ALB | Public load balancer, routes to ECS services |
| ECS Cluster | Fargate-based container orchestration |
| ECS Services (×2) | Run Flask and Express containers |
| CloudWatch Logs | Container log groups |
| IAM Role | ECS task execution permissions |

---

## Teardown (All Parts)

```bash
cd part<N>
terraform destroy
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| EC2 app not responding | SSH in and run `systemctl status flask` / `systemctl status express` |
| ECS task keeps stopping | Check CloudWatch logs at `/ecs/flask-backend` or `/ecs/express-frontend` |
| ECR push denied | Re-run `aws ecr get-login-password` to refresh Docker auth token |
| Terraform state error | Confirm S3 bucket exists and IAM user has `s3:PutObject` permission |
