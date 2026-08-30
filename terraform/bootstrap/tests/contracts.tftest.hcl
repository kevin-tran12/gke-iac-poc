mock_provider "google" {}

mock_provider "google" {
  alias = "billing"
}

run "disposable_project_contract" {
  command = plan

  variables {
    project_id           = "gke-lab-unit-test"
    billing_account      = "000000-000000-000000"
    github_owner_id      = "123456"
    github_repository_id = "789012"
    bootstrap_profile    = "full"
  }

  assert {
    condition     = google_project.lab.auto_create_network == false
    error_message = "The disposable project must not receive a default network."
  }

  assert {
    condition     = google_storage_bucket.terraform_state.uniform_bucket_level_access
    error_message = "Terraform state must use uniform bucket-level access."
  }

  assert {
    condition = (
      google_project.lab.deletion_policy == "PREVENT" &&
      google_storage_bucket.terraform_state.deletion_policy == "PREVENT" &&
      google_storage_bucket.terraform_state.force_destroy == false &&
      google_storage_bucket.terraform_state.soft_delete_policy[0].retention_duration_seconds == 604800
    )
    error_message = "The project and state bucket must resist accidental deletion and retain soft-deleted state."
  }

  assert {
    condition     = length(google_service_account.terraform_phase) == 4
    error_message = "Exactly four phase-specific Terraform identities must be created."
  }

  assert {
    condition = alltrue([
      for phase in ["foundation", "cluster", "delivery", "recovery"] :
      contains(keys(google_service_account.terraform_phase), phase)
    ])
    error_message = "Foundation, cluster, delivery, and recovery identities are required."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.gate_writer) == 3
    error_message = "Normal phase identities must have separate gate-writer bindings."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.dependency_state_reader) == 2
    error_message = "Cluster and delivery identities need read-only access to their upstream Terraform state."
  }

  assert {
    condition = (
      contains(google_project_iam_custom_role.foundation_project_control.permissions, "resourcemanager.projects.update") &&
      !contains(google_project_iam_custom_role.foundation_project_control.permissions, "resourcemanager.projects.move") &&
      !contains(google_project_iam_custom_role.foundation_project_control.permissions, "resourcemanager.projects.delete")
    )
    error_message = "Foundation may maintain project metadata but must not move or delete the project."
  }

  assert {
    condition = alltrue([
      for phase, binding in google_storage_bucket_iam_member.gate_writer :
      !strcontains(binding.condition[0].expression, "objects/gates/'")
    ])
    error_message = "Normal phases must not receive write access to the entire gate prefix."
  }

  assert {
    condition = alltrue([
      for claim in ["repository_id", "repository_owner_id", "ref", "workflow_ref", "job_workflow_ref", "environment"] :
      strcontains(google_iam_workload_identity_pool_provider.github.attribute_condition, claim)
    ])
    error_message = "GitHub federation must restrict immutable repository identity, branch, workflows, and environment."
  }

  assert {
    condition     = google_logging_project_bucket_config.default.retention_days == 30
    error_message = "The default audit-log bucket must have bounded retention."
  }

  assert {
    condition     = length(google_project_iam_audit_config.sensitive_services) == 4
    error_message = "IAM, Secret Manager, Cloud KMS, and state access need explicit Data Access audit logs."
  }
}
