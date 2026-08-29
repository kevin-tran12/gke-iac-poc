mock_provider "google" {}
mock_provider "kubernetes" {}

run "public_edge_contract" {
  command = plan

  variables {
    project_id             = "gke-lab-unit-test"
    cluster_dns_endpoint   = "example.gke.goog"
    cluster_ca_certificate = "Y2E="
    acme_email             = "operator@example.com"
  }

  assert {
    condition     = contains([for rule in google_compute_security_policy.lab.rule : rule.action], "deny(403)")
    error_message = "Cloud Armor must block the preconfigured WAF rule."
  }

  assert {
    condition     = contains([for rule in google_compute_security_policy.lab.rule : rule.action], "rate_based_ban")
    error_message = "Cloud Armor must retain the bounded per-IP rate policy."
  }
}
