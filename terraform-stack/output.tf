output "hostname" {
  value       = module.alb.lb_dns_name
  sensitive   = false
  description = "ALB DNS name to connect frontend"
}
