output "flask_public_ip" {
  description = "Flask server public IP"
  value       = aws_instance.flask_server.public_ip
}

output "flask_url" {
  description = "Flask backend URL"
  value       = "http://${aws_instance.flask_server.public_ip}:5000"
}

output "express_public_ip" {
  description = "Express server public IP"
  value       = aws_instance.express_server.public_ip
}

output "express_url" {
  description = "Express frontend URL"
  value       = "http://${aws_instance.express_server.public_ip}:3000"
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}
