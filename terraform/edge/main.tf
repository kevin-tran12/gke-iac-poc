locals {
  hostname = "${replace(google_compute_global_address.gateway.address, ".", "-")}.nip.io"
  services = toset(["echo", "hello", "hpa-example"])
}

resource "google_compute_global_address" "gateway" {
  name = "gke-lab-gateway"
}

resource "google_compute_security_policy" "lab" {
  name        = "gke-lab-edge"
  description = "Ephemeral GKE lab WAF and rate-limit policy"

  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "Block SQL injection signatures"

    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable')"
      }
    }
  }

  rule {
    action      = "rate_based_ban"
    priority    = 2000
    description = "Bound per-client request bursts"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }

    rate_limit_options {
      conform_action   = "allow"
      exceed_action    = "deny(429)"
      ban_duration_sec = 300
      enforce_on_key   = "IP"

      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }

      ban_threshold {
        count        = 200
        interval_sec = 60
      }
    }
  }

  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow after explicit controls"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

resource "google_monitoring_uptime_check_config" "https" {
  display_name = "GKE lab public HTTPS"
  timeout      = "10s"
  period       = "60s"

  selected_regions = ["USA"]

  http_check {
    path         = "/hello"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      host_id    = local.hostname
      project_id = var.project_id
    }
  }

  content_matchers {
    content = "Hello"
    matcher = "CONTAINS_STRING"
  }
}

resource "kubernetes_manifest" "cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-production"
    }
    spec = {
      acme = {
        email  = var.acme_email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-production-account"
        }
        solvers = [{
          http01 = {
            gatewayHTTPRoute = {
              parentRefs = [{
                name      = "public"
                namespace = "test"
                kind      = "Gateway"
              }]
            }
          }
        }]
      }
    }
  }
}

resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public"
      namespace = "test"
    }
    spec = {
      gatewayClassName = "gke-l7-global-external-managed"
      addresses = [{
        type  = "NamedAddress"
        value = google_compute_global_address.gateway.name
      }]
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            namespaces = { from = "Same" }
          }
        },
        {
          name     = "https"
          hostname = local.hostname
          protocol = "HTTPS"
          port     = 443
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              group = ""
              kind  = "Secret"
              name  = "public-tls"
            }]
          }
          allowedRoutes = {
            namespaces = { from = "Same" }
          }
        },
      ]
    }
  }

  depends_on = [kubernetes_manifest.cluster_issuer]
}

resource "kubernetes_manifest" "certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "public-tls"
      namespace = "test"
    }
    spec = {
      secretName = "public-tls"
      dnsNames   = [local.hostname]
      issuerRef = {
        name = "letsencrypt-production"
        kind = "ClusterIssuer"
      }
    }
  }

  depends_on = [kubernetes_manifest.gateway]
}

resource "kubernetes_manifest" "http_redirect" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "http-redirect"
      namespace = "test"
    }
    spec = {
      parentRefs = [{ name = "public", sectionName = "http" }]
      hostnames  = [local.hostname]
      rules = [{
        filters = [{
          type = "RequestRedirect"
          requestRedirect = {
            scheme     = "https"
            statusCode = 301
          }
        }]
      }]
    }
  }

  depends_on = [kubernetes_manifest.gateway]
}

resource "kubernetes_manifest" "application_routes" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "applications"
      namespace = "test"
    }
    spec = {
      parentRefs = [{ name = "public", sectionName = "https" }]
      hostnames  = [local.hostname]
      rules = [
        {
          matches     = [{ path = { type = "PathPrefix", value = "/echo" } }]
          filters     = [{ type = "URLRewrite", urlRewrite = { path = { type = "ReplacePrefixMatch", replacePrefixMatch = "/" } } }]
          backendRefs = [{ name = "echo", port = 80 }]
        },
        {
          matches     = [{ path = { type = "PathPrefix", value = "/hello" } }]
          backendRefs = [{ name = "hello", port = 80 }]
        },
        {
          matches     = [{ path = { type = "PathPrefix", value = "/hpa" } }]
          backendRefs = [{ name = "hpa-example", port = 80 }]
        },
        {
          matches     = [{ path = { type = "PathPrefix", value = "/api" } }]
          filters     = [{ type = "URLRewrite", urlRewrite = { path = { type = "ReplacePrefixMatch", replacePrefixMatch = "/" } } }]
          backendRefs = [{ name = "gke-lab-api", namespace = "production", port = 80 }]
        },
      ]
    }
  }

  depends_on = [kubernetes_manifest.gateway]
}

resource "kubernetes_manifest" "production_reference_grant" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "public-api-route"
      namespace = "production"
    }
    spec = {
      from = [{
        group     = "gateway.networking.k8s.io"
        kind      = "HTTPRoute"
        namespace = "test"
      }]
      to = [{
        group = ""
        kind  = "Service"
        name  = "gke-lab-api"
      }]
    }
  }
}

resource "kubernetes_manifest" "production_backend_policy" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "GCPBackendPolicy"
    metadata = {
      name      = "gke-lab-api-security"
      namespace = "production"
    }
    spec = {
      default = {
        securityPolicy = google_compute_security_policy.lab.name
      }
      targetRef = {
        group = ""
        kind  = "Service"
        name  = "gke-lab-api"
      }
    }
  }
}

resource "kubernetes_manifest" "backend_policy" {
  for_each = local.services

  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "GCPBackendPolicy"
    metadata = {
      name      = "${each.value}-security"
      namespace = "test"
    }
    spec = {
      default = {
        securityPolicy = google_compute_security_policy.lab.name
      }
      targetRef = {
        group = ""
        kind  = "Service"
        name  = each.value
      }
    }
  }
}
