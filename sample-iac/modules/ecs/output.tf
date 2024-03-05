output "openpayment_service_url" {
  value = "http://${module.alb.lb_dns_name}"
}