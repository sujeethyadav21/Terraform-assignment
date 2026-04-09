output "flask_ecr_url" {
  description = "Flask ECR repository URL"
  value       = aws_ecr_repository.flask.repository_url
}

output "express_ecr_url" {
  description = "Express ECR repository URL"
  value       = aws_ecr_repository.express.repository_url
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "express_app_url" {
  description = "Express frontend accessible via ALB"
  value       = "http://${aws_lb.main.dns_name}"
}

output "flask_app_url" {
  description = "Flask backend accessible via ALB"
  value       = "http://${aws_lb.main.dns_name}:8080"
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}
