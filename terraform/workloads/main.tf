locals {
  namespaces = toset(["test", "staging", "production", "recovery"])
  workload_service_accounts = {
    "staging-api" = {
      namespace = "staging"
      name      = "gke-lab-api"
      gsa       = var.api_service_account
    }
    "staging-worker" = {
      namespace = "staging"
      name      = "gke-lab-worker"
      gsa       = var.worker_service_account
    }
    "production-api" = {
      namespace = "production"
      name      = "gke-lab-api"
      gsa       = var.api_service_account
    }
    "production-worker" = {
      namespace = "production"
      name      = "gke-lab-worker"
      gsa       = var.worker_service_account
    }
  }
}

resource "kubernetes_namespace_v1" "lab" {
  for_each = local.namespaces

  metadata {
    name = each.value
    labels = {
      "pod-security.kubernetes.io/enforce" = each.value == "test" ? "baseline" : "restricted"
      "pod-security.kubernetes.io/audit"   = each.value == "test" ? "baseline" : "restricted"
      "pod-security.kubernetes.io/warn"    = each.value == "test" ? "baseline" : "restricted"
      "gke-lab/ttl"                        = var.environment_ttl
    }
  }
}

resource "kubernetes_resource_quota_v1" "lab" {
  for_each = local.namespaces

  metadata {
    name      = "namespace-budget"
    namespace = kubernetes_namespace_v1.lab[each.value].metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = each.value == "test" ? "3" : "2"
      "requests.memory" = "2Gi"
      "limits.cpu"      = each.value == "test" ? "6" : "4"
      "limits.memory"   = "4Gi"
      "pods"            = "20"
      "services"        = "10"
    }
  }
}

resource "kubernetes_limit_range_v1" "lab" {
  for_each = local.namespaces

  metadata {
    name      = "container-defaults"
    namespace = kubernetes_namespace_v1.lab[each.value].metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "256Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "default_deny" {
  for_each = local.namespaces

  metadata {
    name      = "default-deny"
    namespace = kubernetes_namespace_v1.lab[each.value].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "allow_dns" {
  for_each = local.namespaces

  metadata {
    name      = "allow-dns"
    namespace = kubernetes_namespace_v1.lab[each.value].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }

      ports {
        port     = "53"
        protocol = "UDP"
      }

      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_demo_ingress" {
  metadata {
    name      = "allow-demo-http"
    namespace = kubernetes_namespace_v1.lab["test"].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]

    ingress {
      ports {
        port     = "80"
        protocol = "TCP"
      }

      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }

    egress {
      to {
        pod_selector {}
      }

      ports {
        port     = "80"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_recovery_probes" {
  metadata {
    name      = "allow-test-service-probes"
    namespace = kubernetes_namespace_v1.lab["recovery"].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "test"
          }
        }
      }

      ports {
        port     = "80"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_application_ingress" {
  for_each = toset(["staging", "production"])

  metadata {
    name      = "allow-api-from-namespace"
    namespace = kubernetes_namespace_v1.lab[each.value].metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "gke-lab-api"
      }
    }
    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {}
      }

      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_gateway_to_production_api" {
  metadata {
    name      = "allow-gateway-to-api"
    namespace = kubernetes_namespace_v1.lab["production"].metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "gke-lab-api"
      }
    }
    policy_types = ["Ingress"]

    ingress {
      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_application_egress" {
  for_each = toset(["staging", "production"])

  metadata {
    name      = "allow-google-apis-and-telemetry"
    namespace = kubernetes_namespace_v1.lab[each.value].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    egress {
      to {
        pod_selector {}
      }

      ports {
        port     = "80"
        protocol = "TCP"
      }
    }

    egress {
      to {
        ip_block {
          cidr = "169.254.169.254/32"
        }
      }

      ports {
        port     = "80"
        protocol = "TCP"
      }
    }

    egress {
      to {
        ip_block {
          cidr = "10.0.0.0/8"
        }
      }

      ports {
        port     = "5432"
        protocol = "TCP"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "observability"
          }
        }
        pod_selector {
          match_labels = {
            app = "otel-collector"
          }
        }
      }

      ports {
        port     = "4317"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_service_account_v1" "workload" {
  for_each = local.workload_service_accounts

  metadata {
    name      = each.value.name
    namespace = kubernetes_namespace_v1.lab[each.value.namespace].metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = each.value.gsa
    }
  }
}

resource "kubernetes_manifest" "test_deployments" {
  for_each = {
    echo = {
      image = var.echo_image
      port  = 8080
      cpu   = "50m"
    }
    hello = {
      image = var.hello_image
      port  = 8080
      cpu   = "50m"
    }
    hpa-example = {
      image = var.hpa_image
      port  = 80
      cpu   = "400m"
    }
  }

  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = each.key
      namespace = kubernetes_namespace_v1.lab["test"].metadata[0].name
      labels    = { app = each.key }
    }
    spec = {
      replicas = each.key == "hello" ? 3 : 1
      selector = { matchLabels = { app = each.key } }
      template = {
        metadata = { labels = { app = each.key } }
        spec = {
          automountServiceAccountToken = false
          nodeSelector                 = each.key == "hpa-example" ? { pool = "applications" } : {}
          tolerations = each.key == "hpa-example" ? [{
            key      = "cloud.google.com/gke-spot"
            operator = "Equal"
            value    = "true"
            effect   = "NoSchedule"
          }] : []
          securityContext = {
            seccompProfile = {
              type = "RuntimeDefault"
            }
          }
          containers = [{
            name            = each.key
            image           = each.value.image
            imagePullPolicy = "IfNotPresent"
            ports           = [{ name = "http", containerPort = each.value.port }]
            readinessProbe = {
              httpGet             = { path = "/", port = "http" }
              initialDelaySeconds = 2
              periodSeconds       = 3
            }
            livenessProbe = {
              httpGet             = { path = "/", port = "http" }
              initialDelaySeconds = 10
              periodSeconds       = 10
            }
            resources = {
              requests = { cpu = each.value.cpu, memory = "32Mi" }
              limits   = { cpu = "1000m", memory = "128Mi" }
            }
            securityContext = {
              allowPrivilegeEscalation = false
              runAsNonRoot             = each.key != "hpa-example"
              runAsUser                = each.key == "hpa-example" ? 0 : 65532
              capabilities             = { drop = ["ALL"] }
              readOnlyRootFilesystem   = false
            }
          }]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "test_services" {
  for_each = {
    echo        = 8080
    hello       = 8080
    hpa-example = 80
  }

  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = each.key
      namespace = kubernetes_namespace_v1.lab["test"].metadata[0].name
    }
    spec = {
      type     = "ClusterIP"
      selector = { app = each.key }
      ports = [{
        name       = "http"
        port       = 80
        targetPort = each.value
      }]
    }
  }

  depends_on = [kubernetes_manifest.test_deployments]
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "hpa_example" {
  metadata {
    name      = "hpa-example"
    namespace = kubernetes_namespace_v1.lab["test"].metadata[0].name
  }

  spec {
    min_replicas = 1
    max_replicas = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "hpa-example"
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 50
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.test_deployments]
}

resource "kubernetes_manifest" "recovery_stateful_set" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "StatefulSet"
    metadata = {
      name      = "recovery-proof"
      namespace = kubernetes_namespace_v1.lab["recovery"].metadata[0].name
    }
    spec = {
      serviceName = "recovery-proof"
      replicas    = 1
      selector    = { matchLabels = { app = "recovery-proof" } }
      template = {
        metadata = { labels = { app = "recovery-proof" } }
        spec = {
          automountServiceAccountToken = false
          securityContext = {
            runAsNonRoot = true
            runAsUser    = 65532
            runAsGroup   = 65532
            fsGroup      = 65532
            seccompProfile = {
              type = "RuntimeDefault"
            }
          }
          containers = [{
            name    = "recovery-proof"
            image   = var.recovery_image
            command = ["sh", "-c", "test -f /data/proof.txt || date -u +%FT%TZ > /data/proof.txt; exec sleep 86400"]
            resources = {
              requests = { cpu = "10m", memory = "16Mi" }
              limits   = { cpu = "100m", memory = "64Mi" }
            }
            securityContext = {
              allowPrivilegeEscalation = false
              capabilities             = { drop = ["ALL"] }
              readOnlyRootFilesystem   = true
            }
            volumeMounts = [{ name = "data", mountPath = "/data" }]
          }]
        }
      }
      volumeClaimTemplates = [{
        metadata = { name = "data" }
        spec = {
          accessModes      = ["ReadWriteOnce"]
          storageClassName = "standard-rwo"
          resources        = { requests = { storage = "1Gi" } }
        }
      }]
    }
  }
}
