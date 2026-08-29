resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name = "observability"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 600

  set = concat([
    {
      name  = "crds.enabled"
      value = "true"
    },
    {
      name  = "config.enableGatewayAPI"
      value = "true"
    },
    {
      name  = "global.leaderElection.namespace"
      value = "cert-manager"
    },
    ], flatten([
      for component, image in var.cert_manager_images : [
        {
          name  = component == "controller" ? "image.repository" : "${component}.image.repository"
          value = split("@", image)[0]
        },
        {
          name  = component == "controller" ? "image.digest" : "${component}.image.digest"
          value = split("@", image)[1]
        },
      ]
  ]))

  depends_on = [kubernetes_namespace_v1.cert_manager]
}

resource "kubernetes_service_account_v1" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = var.telemetry_service_account
    }
  }
}

resource "kubernetes_config_map_v1" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
  }

  data = {
    "config.yaml" = <<-YAML
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318
      processors:
        batch: {}
        memory_limiter:
          check_interval: 1s
          limit_mib: 128
      exporters:
        debug:
          verbosity: basic
        googlecloud: {}
      service:
        pipelines:
          traces:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [googlecloud, debug]
          metrics:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [googlecloud, debug]
    YAML
  }
}

resource "kubernetes_deployment_v1" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels = {
      app = "otel-collector"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "otel-collector"
      }
    }

    template {
      metadata {
        labels = {
          app = "otel-collector"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.otel_collector.metadata[0].name

        security_context {
          run_as_non_root = true
          run_as_user     = 10001
          run_as_group    = 10001
          fs_group        = 10001
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "collector"
          image             = var.otel_collector_image
          image_pull_policy = "IfNotPresent"
          args              = ["--config=/conf/config.yaml"]

          port {
            name           = "otlp-grpc"
            container_port = 4317
          }

          port {
            name           = "otlp-http"
            container_port = 4318
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "192Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/conf"
            read_only  = true
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.otel_collector.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
  }

  spec {
    selector = {
      app = "otel-collector"
    }

    port {
      name        = "otlp-grpc"
      port        = 4317
      target_port = "otlp-grpc"
    }

    port {
      name        = "otlp-http"
      port        = 4318
      target_port = "otlp-http"
    }
  }
}
