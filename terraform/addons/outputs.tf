output "cert_manager_namespace" { value = helm_release.cert_manager.namespace }
output "otel_endpoint" { value = "otel-collector.observability.svc.cluster.local:4317" }
