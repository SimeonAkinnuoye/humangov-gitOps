output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "lb_role_arn" {
  value = module.lb_role.iam_role_arn
}

output "pod_execution_role_arn" {
  value = module.irsa_humangov_app.iam_role_arn
}