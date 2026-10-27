# Nothing is open to the internet, so there are no public URLs. Each "open_*" output below is
# a ready-made command that starts an AWS Session Manager tunnel. Keep it running in its own
# PowerShell window and open the address in the description in your browser.
# Needs the AWS CLI and the Session Manager plugin (see docs/SETUP.md).

output "open_jenkins" {
  description = "Tunnel for Jenkins: then open http://localhost:8080"
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.ci.id} --document-name AWS-StartPortForwardingSession --parameters \"portNumber=8080,localPortNumber=8080\""
}

output "open_website" {
  description = "Tunnel for the website: then open http://localhost:8081"
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.k8s.id} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters \"host=${aws_instance.k8s.private_ip},portNumber=80,localPortNumber=8081\""
}

output "open_grafana" {
  description = "Tunnel for Grafana: then open http://localhost:3000"
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.k8s.id} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters \"host=${aws_instance.k8s.private_ip},portNumber=30300,localPortNumber=3000\""
}

output "open_prometheus" {
  description = "Tunnel for Prometheus: then open http://localhost:9090"
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.k8s.id} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters \"host=${aws_instance.k8s.private_ip},portNumber=30090,localPortNumber=9090\""
}

output "shell_ci_server" {
  description = "Shell on the CI server (Session Manager)"
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.ci.id}"
}

output "shell_k8s_node" {
  description = "Shell on the Kubernetes node (Session Manager)"
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.k8s.id}"
}

output "grafana_admin_password" {
  description = "Grafana admin password (user: admin). Show it with: terraform output -raw grafana_admin_password"
  value       = random_password.grafana.result
  sensitive   = true
}

output "ecr_repository_url" {
  description = "Container registry where Jenkins pushes images."
  value       = aws_ecr_repository.app.repository_url
}
