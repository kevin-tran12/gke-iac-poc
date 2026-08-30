locals {
  service_catalog = {
    "artifactregistry.googleapis.com"     = { layer = 3, profile = "core", consumer = "mirrored and application images" }
    "billingbudgets.googleapis.com"       = { layer = 1, profile = "core", consumer = "lab budget alerts" }
    "cloudbilling.googleapis.com"         = { layer = 1, profile = "core", consumer = "project billing association" }
    "cloudresourcemanager.googleapis.com" = { layer = 1, profile = "core", consumer = "project lifecycle and IAM" }
    "compute.googleapis.com"              = { layer = 2, profile = "core", consumer = "VPC and GKE networking" }
    "container.googleapis.com"            = { layer = 4, profile = "core", consumer = "GKE control plane" }
    "dns.googleapis.com"                  = { layer = 3, profile = "core", consumer = "private service discovery" }
    "iam.googleapis.com"                  = { layer = 1, profile = "core", consumer = "service accounts and federation" }
    "iamcredentials.googleapis.com"       = { layer = 1, profile = "core", consumer = "keyless service-account credentials" }
    "logging.googleapis.com"              = { layer = 1, profile = "core", consumer = "audit and workload logs" }
    "monitoring.googleapis.com"           = { layer = 1, profile = "core", consumer = "metrics and alerting" }
    "policytroubleshooter.googleapis.com" = { layer = 1, profile = "core", consumer = "positive and negative IAM tests" }
    "pubsub.googleapis.com"               = { layer = 3, profile = "core", consumer = "durable job delivery" }
    "secretmanager.googleapis.com"        = { layer = 3, profile = "core", consumer = "runtime secret metadata" }
    "serviceusage.googleapis.com"         = { layer = 1, profile = "core", consumer = "API lifecycle" }
    "sts.googleapis.com"                  = { layer = 1, profile = "core", consumer = "GitHub token exchange" }
    "storage.googleapis.com"              = { layer = 1, profile = "core", consumer = "Terraform state and durable objects" }
    "binaryauthorization.googleapis.com"  = { layer = 7, profile = "full", consumer = "signed-image admission lab" }
    "cloudbuild.googleapis.com"           = { layer = 7, profile = "full", consumer = "signed container builds" }
    "clouddeploy.googleapis.com"          = { layer = 7, profile = "full", consumer = "staging and production promotion" }
    "cloudkms.googleapis.com"             = { layer = 7, profile = "full", consumer = "attestation signing key" }
    "containeranalysis.googleapis.com"    = { layer = 7, profile = "full", consumer = "Binary Authorization attestations" }
    "gkebackup.googleapis.com"            = { layer = 9, profile = "full", consumer = "Backup for GKE restore lab" }
    "servicenetworking.googleapis.com"    = { layer = 3, profile = "full", consumer = "Cloud SQL private services access" }
    "sqladmin.googleapis.com"             = { layer = 3, profile = "full", consumer = "private Cloud SQL data profile" }
  }

  enabled_services = {
    for service, metadata in local.service_catalog : service => metadata
    if metadata.profile == "core" || var.bootstrap_profile == "full"
  }

  phase_service_accounts = {
    foundation = {
      account_id   = "github-terraform-foundation"
      display_name = "GitHub Terraform foundation layers 1-3"
      environments = toset(["foundation"])
    }
    cluster = {
      account_id   = "github-terraform-cluster"
      display_name = "GitHub Terraform cluster layers 4-6"
      environments = toset(["cluster"])
    }
    delivery = {
      account_id   = "github-terraform-delivery"
      display_name = "GitHub Terraform delivery layers 7-8"
      environments = toset(["delivery", "production"])
    }
    recovery = {
      account_id   = "github-terraform-recovery"
      display_name = "GitHub Terraform recovery and teardown"
      environments = toset(["recovery", "automated-reaper", "destructive-labs", "final-delete"])
    }
  }

  phase_environment_bindings = merge([
    for phase, config in local.phase_service_accounts : {
      for environment in config.environments : "${phase}:${environment}" => {
        phase       = phase
        environment = environment
      }
    }
  ]...)

  phase_project_roles = {
    foundation = toset([
      "roles/artifactregistry.admin",
      "roles/billing.projectManager",
      "roles/cloudsql.admin",
      "roles/compute.networkAdmin",
      "roles/dns.admin",
      "roles/iam.roleAdmin",
      "roles/iam.serviceAccountAdmin",
      "roles/iam.serviceAccountUser",
      "roles/iam.workloadIdentityPoolAdmin",
      "roles/logging.admin",
      "roles/monitoring.editor",
      "roles/pubsub.admin",
      "roles/resourcemanager.projectIamAdmin",
      "roles/secretmanager.admin",
      "roles/servicenetworking.networksAdmin",
      "roles/serviceusage.serviceUsageAdmin",
    ])
    cluster = toset([
      "roles/compute.networkUser",
      "roles/container.admin",
      "roles/iam.serviceAccountAdmin",
      "roles/iam.serviceAccountUser",
      "roles/resourcemanager.projectIamAdmin",
    ])
    delivery = toset([
      "roles/binaryauthorization.policyEditor",
      "roles/clouddeploy.admin",
      "roles/cloudkms.admin",
      "roles/compute.loadBalancerAdmin",
      "roles/compute.securityAdmin",
      "roles/container.admin",
      "roles/containeranalysis.admin",
      "roles/iam.serviceAccountUser",
      "roles/monitoring.editor",
    ])
    # Teardown must delete resources from every runtime phase. This deliberately
    # broad union is isolated behind teardown-only workflows and environments.
    recovery = toset([
      "roles/artifactregistry.admin",
      "roles/binaryauthorization.policyEditor",
      "roles/cloudbuild.builds.editor",
      "roles/clouddeploy.admin",
      "roles/cloudkms.admin",
      "roles/cloudsql.admin",
      "roles/compute.networkAdmin",
      "roles/compute.securityAdmin",
      "roles/container.admin",
      "roles/containeranalysis.admin",
      "roles/dns.admin",
      "roles/gkebackup.admin",
      "roles/iam.serviceAccountAdmin",
      "roles/iam.serviceAccountUser",
      "roles/monitoring.editor",
      "roles/pubsub.admin",
      "roles/billing.projectManager",
      "roles/resourcemanager.projectIamAdmin",
      "roles/resourcemanager.projectDeleter",
      "roles/secretmanager.admin",
      "roles/servicenetworking.networksAdmin",
      "roles/storage.admin",
    ])
  }

  phase_role_bindings = merge([
    for phase, roles in local.phase_project_roles : {
      for role in roles : "${phase}:${role}" => { phase = phase, role = role }
    }
  ]...)

  phase_state_prefixes = {
    foundation = ["state/bootstrap/", "state/network/", "state/platform/", "reviewed-plans/layer-1/", "reviewed-plans/layer-2/", "reviewed-plans/layer-3/"]
    cluster    = ["state/cluster/", "state/addons/", "state/workloads/", "reviewed-plans/layer-4/", "reviewed-plans/layer-5/", "reviewed-plans/layer-6/"]
    delivery   = ["state/delivery/", "state/edge/", "reviewed-plans/layer-7/", "reviewed-plans/layer-8/"]
    recovery   = [""]
  }

  phase_gate_write_prefixes = {
    foundation = ["gates/layer-1.json", "gates/layer-2.json", "gates/layer-3.json", "gates/environment-lease.json"]
    cluster    = ["gates/layer-4.json", "gates/layer-5.json", "gates/layer-6.json"]
    delivery   = ["gates/layer-7.json", "gates/layer-8.json"]
  }

  phase_dependency_state_prefixes = {
    cluster  = ["state/network/", "state/platform/"]
    delivery = ["state/network/", "state/platform/", "state/cluster/"]
  }

  audit_services = toset([
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "storage.googleapis.com",
  ])

  repository_workflow_ref = "${var.github_repository}/.github/workflows/provision-through-layer.yml@refs/heads/main"
  reusable_workflow_ref   = "${var.github_repository}/.github/workflows/integration-layer.yml@refs/heads/main"
  promotion_workflow_ref  = "${var.github_repository}/.github/workflows/promote-production.yml@refs/heads/main"
  reaper_workflow_ref     = "${var.github_repository}/.github/workflows/reaper.yml@refs/heads/main"
  teardown_workflow_ref   = "${var.github_repository}/.github/workflows/teardown.yml@refs/heads/main"
  final_delete_ref        = "${var.github_repository}/.github/workflows/final-delete.yml@refs/heads/main"
}

resource "google_project" "lab" {
  project_id          = var.project_id
  name                = var.project_name
  billing_account     = var.billing_account
  org_id              = var.organization_id
  auto_create_network = false
  deletion_policy     = "PREVENT"
  labels              = var.labels
}

resource "google_project_service" "required" {
  for_each = local.enabled_services

  project            = google_project.lab.project_id
  service            = each.key
  disable_on_destroy = true
}

resource "google_storage_bucket" "terraform_state" {
  project                     = google_project.lab.project_id
  name                        = "${google_project.lab.project_id}-tfstate"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  deletion_policy             = "PREVENT"

  versioning {
    enabled = true
  }

  soft_delete_policy {
    retention_duration_seconds = 604800
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

resource "google_service_account" "terraform_phase" {
  for_each = local.phase_service_accounts

  project      = google_project.lab.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
  description  = "Keyless GitHub identity restricted to the ${each.key} phase."
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
    "google.subject"                = "assertion.sub"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner"    = "assertion.repository_owner"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
    "attribute.job_workflow_ref"    = "assertion.job_workflow_ref"
    "attribute.environment"         = "assertion.environment"
  }

  attribute_condition = <<-EOT
    assertion.repository_id == '${var.github_repository_id}' &&
    assertion.repository_owner_id == '${var.github_owner_id}' &&
    assertion.ref == 'refs/heads/main' &&
    (
      (assertion.workflow_ref == '${local.repository_workflow_ref}' && assertion.job_workflow_ref == '${local.reusable_workflow_ref}' && assertion.environment in ['foundation', 'cluster', 'delivery', 'recovery']) ||
      (assertion.workflow_ref == '${local.promotion_workflow_ref}' && assertion.environment == 'production') ||
      (assertion.workflow_ref == '${local.reaper_workflow_ref}' && assertion.environment == 'automated-reaper') ||
      (assertion.workflow_ref == '${local.teardown_workflow_ref}' && assertion.environment == 'destructive-labs') ||
      (assertion.workflow_ref == '${local.final_delete_ref}' && assertion.environment == 'final-delete')
    )
  EOT

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "phase_wif" {
  for_each = local.phase_environment_bindings

  service_account_id = google_service_account.terraform_phase[each.value.phase].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.environment/${each.value.environment}"
}

resource "google_project_iam_custom_role" "foundation_storage_control" {
  project     = google_project.lab.project_id
  role_id     = "terraformFoundationStorageControl"
  title       = "Terraform Foundation Storage Control"
  description = "Create and configure lab buckets without project-wide object payload access."
  permissions = [
    "storage.buckets.create",
    "storage.buckets.delete",
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.buckets.list",
    "storage.buckets.setIamPolicy",
    "storage.buckets.update",
  ]
}

resource "google_project_iam_custom_role" "foundation_project_control" {
  project     = google_project.lab.project_id
  role_id     = "terraformFoundationProjectControl"
  title       = "Terraform Foundation Project Control"
  description = "Maintain project metadata without permission to move or delete the project."
  permissions = [
    "resourcemanager.projects.get",
    "resourcemanager.projects.update",
  ]
}

resource "google_project_iam_member" "phase_roles" {
  for_each = local.phase_role_bindings

  project = google_project.lab.project_id
  role    = each.value.role
  member  = google_service_account.terraform_phase[each.value.phase].member
}

resource "google_project_iam_member" "foundation_storage_control" {
  project = google_project.lab.project_id
  role    = google_project_iam_custom_role.foundation_storage_control.name
  member  = google_service_account.terraform_phase["foundation"].member
}

resource "google_project_iam_member" "foundation_project_control" {
  project = google_project.lab.project_id
  role    = google_project_iam_custom_role.foundation_project_control.name
  member  = google_service_account.terraform_phase["foundation"].member
}

resource "google_storage_bucket_iam_member" "state_phase" {
  for_each = local.phase_state_prefixes

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.terraform_phase[each.key].member

  condition {
    title       = "${each.key}-terraform-prefixes"
    description = "Limit ${each.key} to its state, reviewed plans, and gate evidence."
    expression = join(" || ", concat(
      ["resource.name == 'projects/_/buckets/${google_storage_bucket.terraform_state.name}'"],
      [for prefix in each.value : "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.terraform_state.name}/objects/${prefix}')"]
    ))
  }
}

resource "google_storage_bucket_iam_member" "state_bucket_metadata" {
  for_each = local.phase_service_accounts

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.bucketViewer"
  member = google_service_account.terraform_phase[each.key].member
}

resource "google_storage_bucket_iam_member" "dependency_state_reader" {
  for_each = local.phase_dependency_state_prefixes

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.terraform_phase[each.key].member

  condition {
    title       = "${each.key}-dependency-state-reader"
    description = "Read upstream Terraform outputs required to derive ${each.key} inputs."
    expression = join(" || ", concat(
      ["resource.name == 'projects/_/buckets/${google_storage_bucket.terraform_state.name}'"],
      [for prefix in each.value : "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.terraform_state.name}/objects/${prefix}')"]
    ))
  }
}

resource "google_storage_bucket_iam_member" "gate_reader" {
  for_each = local.phase_gate_write_prefixes

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.terraform_phase[each.key].member

  condition {
    title       = "${each.key}-gate-reader"
    description = "Allow ${each.key} to verify prerequisite gate evidence without rewriting it."
    expression  = "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.terraform_state.name}/objects/gates/')"
  }
}

resource "google_storage_bucket_iam_member" "gate_writer" {
  for_each = local.phase_gate_write_prefixes

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.terraform_phase[each.key].member

  condition {
    title       = "${each.key}-gate-writer"
    description = "Allow ${each.key} to publish only its own layer acceptance records."
    expression = join(" || ", [
      for prefix in each.value : "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.terraform_state.name}/objects/${prefix}')"
    ])
  }
}

resource "google_billing_account_iam_member" "foundation_billing" {
  for_each = toset(["roles/billing.costsManager", "roles/billing.user"])

  billing_account_id = var.billing_account
  role               = each.value
  member             = google_service_account.terraform_phase["foundation"].member
}

resource "google_project_iam_audit_config" "sensitive_services" {
  for_each = local.audit_services

  project = google_project.lab.project_id
  service = each.value

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_logging_project_bucket_config" "default" {
  project        = google_project.lab.project_id
  location       = "global"
  bucket_id      = "_Default"
  retention_days = 30

  depends_on = [google_project_service.required]
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
