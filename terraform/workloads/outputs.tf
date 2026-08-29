output "namespaces" { value = keys(kubernetes_namespace_v1.lab) }
output "echo_service" { value = "echo.test.svc.cluster.local" }
output "hello_service" { value = "hello.test.svc.cluster.local" }
output "hpa_service" { value = "hpa-example.test.svc.cluster.local" }
