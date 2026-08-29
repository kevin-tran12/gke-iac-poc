locals {
  services = toset([
    "artifactregistry.googleapis.com",
    "binaryauthorization.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "dns.googleapis.com",
    "gkebackup.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "sqladmin.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
  ])

  # Only these reviewed deployment workflows, running from the protected main
  # branch, may impersonate the privileged Terraform apply service account.
  apply_workflow_refs = toset([
    "${var.github_repository}/.github/workflows/promote-production.yml@refs/heads/main",
    "${var.github_repository}/.github/workflows/provision-through-layer.yml@refs/heads/main",
    "${var.github_repository}/.github/workflows/reaper.yml@refs/heads/main",
    "${var.github_repository}/.github/workflows/run-full-lab.yml@refs/heads/main",
    "${var.github_repository}/.github/workflows/teardown.yml@refs/heads/main",
  ])
}

resource "google_project" "lab" {
  project_id          = var.project_id
  name                = var.project_name
  billing_account     = var.billing_account
  org_id              = var.organization_id
  auto_create_network = false
  labels              = var.labels
}

resource "google_project_service" "required" {
  for_each = local.services

  project            = google_project.lab.project_id
  service            = each.value
  disable_on_destroy = true
}

resource "google_storage_bucket" "terraform_state" {
  project                     = google_project.lab.project_id
  name                        = "${google_project.lab.project_id}-tfstate"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_service_account" "terraform_plan" {
  project      = google_project.lab.project_id
  account_id   = "github-terraform-plan"
  display_name = "GitHub Terraform read-only plan"
}

resource "google_service_account" "terraform_apply" {
  project      = google_project.lab.project_id
  account_id   = "github-terraform-apply"
  display_name = "GitHub Terraform gated apply"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.lab.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "Keyless GitHub authentication for the portfolio repository"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.lab.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_id"    = "assertion.repository_id"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.workflow_ref"     = "assertion.workflow_ref"
  }

  attribute_condition = "assertion.repository_id == '${var.github_repository_id}' && assertion.repository_owner_id == '${var.github_owner_id}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.terraform_plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_id/${var.github_repository_id}"
}

resource "google_service_account_iam_member" "apply_wif" {
  for_each = local.apply_workflow_refs

  service_account_id = google_service_account.terraform_apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.workflow_ref/${each.value}"
}

resource "google_project_iam_member" "plan_roles" {
  for_each = toset([
    "roles/browser",
    "roles/iam.securityReviewer",
    "roles/viewer",
  ])

  project = google_project.lab.project_id
  role    = each.value
  member  = google_service_account.terraform_plan.member
}

resource "google_project_iam_member" "apply_roles" {
  for_each = toset([
    "roles/artifactregistry.admin",
    "roles/binaryauthorization.policyEditor",
    "roles/cloudbuild.builds.editor",
    "roles/clouddeploy.admin",
    "roles/cloudkms.admin",
    "roles/cloudsql.admin",
    "roles/compute.networkAdmin",
    "roles/container.admin",
    "roles/containeranalysis.admin",
    "roles/dns.admin",
    "roles/gkebackup.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/monitoring.editor",
    "roles/pubsub.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/secretmanager.admin",
    "roles/servicenetworking.networksAdmin",
    "roles/storage.admin",
  ])

  project = google_project.lab.project_id
  role    = each.value
  member  = google_service_account.terraform_apply.member
}

resource "google_storage_bucket_iam_member" "state_plan" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.terraform_plan.member
}

resource "google_storage_bucket_iam_member" "state_apply" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.terraform_apply.member
}

resource "google_billing_budget" "lab" {
  provider = google.billing

  billing_account = var.billing_account
  display_name    = "${var.project_name} budget"

  budget_filter {
    projects = ["projects/${google_project.lab.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_amount_usd)
    }
  }

  dynamic "threshold_rules" {
    for_each = toset([0.25, 0.5, 0.75, 1.0])
    content {
      threshold_percent = threshold_rules.value
    }
  }

  depends_on = [google_project_service.required]
}
