package gates

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func repositoryRoot(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "terraform")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("repository root not found")
		}
		dir = parent
	}
}

func content(t *testing.T, name string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(repositoryRoot(t), filepath.FromSlash(name)))
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func requireContains(t *testing.T, name string, values ...string) {
	t.Helper()
	c := content(t, name)
	for _, value := range values {
		if !strings.Contains(c, value) {
			t.Errorf("%s does not contain %q", name, value)
		}
	}
}

func requireNotContains(t *testing.T, name string, values ...string) {
	t.Helper()
	c := content(t, name)
	for _, value := range values {
		if strings.Contains(c, value) {
			t.Errorf("%s unexpectedly contains %q", name, value)
		}
	}
}

func TestLayer01BootstrapIdentityAndCostControls(t *testing.T) {
	requireContains(t, "terraform/bootstrap/main.tf",
		"auto_create_network = false", "google_billing_budget", "github_repository_id",
		"github_owner_id", "org_id              = var.organization_id",
		"roles/iam.workloadIdentityUser", "uniform_bucket_level_access = true",
		`"attribute.workflow_ref"`, `"attribute.job_workflow_ref"`, `"attribute.environment"`,
		"assertion.ref == 'refs/heads/main'", "local.phase_service_accounts",
		`"billingbudgets.googleapis.com"`, `"policytroubleshooter.googleapis.com"`,
		"bootstrap_profile == \"full\"", "depends_on = [google_project_service.required]",
		"force_destroy               = false", "deletion_policy             = \"PREVENT\"",
		"soft_delete_policy", "google_project_iam_audit_config", "retention_days = 30",
		"terraformFoundationStorageControl", "phase_state_prefixes")
	requireContains(t, "terraform/bootstrap/outputs.tf",
		"terraform_foundation_service_account", "terraform_cluster_service_account",
		"terraform_delivery_service_account", "terraform_recovery_service_account",
		"budget_resource_name", "google_billing_budget.lab.id")
	requireContains(t, "terraform/bootstrap/versions.tf",
		`alias                 = "billing"`, "billing_project       = var.project_id",
		"user_project_override = true")
	requireContains(t, "scripts/gates/common.sh",
		`TF_VAR_project_id="$(state_output bootstrap project_id)"`,
		`TF_STATE_BUCKET="$(state_output bootstrap state_bucket)"`,
		"refresh_bootstrap_outputs")
	requireContains(t, "scripts/gates/live/layer-01.sh",
		"bootstrap-project.json", "enabled_service_catalog", "bootstrap-budget.json",
		"bootstrap-state-bucket.json", "uniform_bucket_level_access",
		"public_access_prevention", ".soft_delete_policy.retentionDurationSeconds",
		`== "enforced"`, "--managed-by=user",
		"budget_resource_name", "policy-intelligence troubleshoot-policy iam",
		"CAN_ACCESS", "CANNOT_ACCESS", "UNKNOWN_INFO", "roles/iam.denyReviewer")
	requireContains(t, "terraform/bootstrap/README.md",
		"roles/iam.denyReviewer", "OPERATOR_ACCOUNT", "FOUNDATION_ACCOUNT",
		"organization bootstrap prerequisite")
	requireContains(t, ".github/workflows/integration-layer.yml",
		"TERRAFORM_FOUNDATION_SERVICE_ACCOUNT", "TERRAFORM_CLUSTER_SERVICE_ACCOUNT",
		"TERRAFORM_DELIVERY_SERVICE_ACCOUNT", "TERRAFORM_RECOVERY_SERVICE_ACCOUNT")
	requireContains(t, "scripts/adopt-project.sh",
		"billingAccountName", "expected_organization", "terraform -chdir=terraform/bootstrap import")
	requireContains(t, "scripts/teardown-final.sh", "CONFIRM_FINAL_DELETE")
	requireContains(t, ".github/workflows/wif-negative-test.yml", "Require federation denial")
	requireNotContains(t, "terraform/bootstrap/main.tf",
		"google_service_account_key", `"roles/secretmanager.secretAccessor"`,
		`"roles/cloudkms.signerVerifier"`)
	requireNotContains(t, ".github/workflows/integration-layer.yml", "TERRAFORM_APPLY_SERVICE_ACCOUNT")
}

func TestGateScriptsUseThePinnedContainerToolchain(t *testing.T) {
	requireContains(t, "scripts/gates/check-prerequisites.sh", "date -u -d", "expires_epoch > now_epoch")
	requireContains(t, "scripts/reap-if-expired.sh", "date -u -d", "expires_epoch <= now_epoch")
	requireNotContains(t, "scripts/gates/check-prerequisites.sh", "python3")
	requireNotContains(t, "scripts/reap-if-expired.sh", "python3")
	requireNotContains(t, "tests/labs/pubsub-redelivery.sh", "python3")
}

func TestGateEvidenceUsesCumulativeSourceDigests(t *testing.T) {
	requireContains(t, "scripts/gates/layer-source-digest.sh",
		"changing a later test does not invalidate earlier proof", "terraform/bootstrap",
		"terraform/network", "terraform/platform", "terraform/recovery", "scripts/gates/live/layer-09.sh", "git hash-object")
	requireContains(t, "scripts/gates/check-prerequisites.sh",
		"git merge-base --is-ancestor", ".source_digest // empty", "layer-source-digest.sh", "verified",
		"terraform_states", "state lineage changed", "state serial changed")
	requireContains(t, "scripts/gates/record-result.sh",
		"schema_version", "planned|applied|verified|failed|destroyed", "terraform_states", "layer-source-digest.sh")
	requireContains(t, "scripts/gates/common.sh",
		"apply and verification require a clean working tree", "git status --porcelain --untracked-files=normal")
}

func TestLayer00SeparatesPlanApplyAndVerification(t *testing.T) {
	requireContains(t, "Makefile", "plan-layer:", "apply-layer:", "verify-layer:", "destroy-layer:")
	requireContains(t, "scripts/gates/plan-layer.sh", "input_digest", "plan_digest", "PLAN_STORE_URI")
	requireContains(t, "scripts/gates/apply-layer.sh", "validate-plan.sh", "create-lease.sh")
	requireContains(t, "scripts/gates/validate-plan.sh",
		"saved plan digest does not match its manifest", "Terraform inputs changed after planning", "saved plan has expired")
	requireContains(t, "scripts/gates/verify-layer.sh", "post-apply drift detected", "record-result.sh \"$layer\" verified")
	requireContains(t, "scripts/gates/run-layer.sh", "APPLY=true is no longer supported")
	requireContains(t, "scripts/reap-if-expired.sh", "environment-lease.json", "Later gate runs cannot extend it")
}

func TestLayer02NetworkIsPrivateByDefault(t *testing.T) {
	requireContains(t, "terraform/network/main.tf",
		"private_ip_google_access = true", "secondary_ip_range", "log_config", "var.enable_nat ? 1 : 0",
		"overlapping_cidr_pairs", "non_private_cidr_ranges", "maximum_cluster_nodes",
		"INTERVAL_10_MIN", "EXCLUDE_ALL_METADATA", "google_compute_global_address")
	requireContains(t, "terraform/network/variables.tf",
		"10.10.0.0/20", "10.20.0.0/16", "10.30.0.0/20", "10.40.0.0/16",
		"maximum_pods_per_node", "minimum_service_addresses")
	requireContains(t, "terraform/network/tests/contracts.tftest.hcl",
		"overlapping_ranges_are_rejected", "public_ranges_are_rejected",
		"insufficient_pod_capacity_is_rejected", "nat_is_bounded_to_the_gke_subnet")
	requireContains(t, "scripts/gates/live/layer-02.sh",
		"network-routes.json", "network-firewall-rules.json", "compute-instances.json",
		"default_network_absent", "cloud-nat-ip-info.json")
	requireContains(t, "terraform/platform/main.tf", "var.private_services_range_name")
	requireNotContains(t, "terraform/platform/main.tf", `resource "google_compute_global_address" "private_services"`)
}

func TestLayer03PlatformDurabilityAndLifecycle(t *testing.T) {
	requireContains(t, "terraform/platform/main.tf",
		"dead_letter_policy", "max_delivery_attempts = 5", "public_access_prevention",
		`role   = "roles/storage.bucketViewer"`, `resource "google_storage_bucket_iam_member" "cloud_build_source"`,
		`resource "google_project_service_identity" "cloud_deploy"`,
		"member             = google_project_service_identity.cloud_deploy.member")
	requireNotContains(t, "terraform/platform/main.tf", `"roles/storage.objectViewer",`)
	requireContains(t, "app/internal/objectstore/gcs.go", "DoesNotExist: true", "ErrAlreadyExists")
	requireNotContains(t, "terraform/platform/main.tf", "google_secret_manager_secret_version")
	requireContains(t, "cloudbuild.yaml", "requestedVerifyOption: VERIFIED", "api-sbom", "${_REGISTRY}")
	requireContains(t, "scripts/build-release.sh", `--gcs-source-staging-dir="gs://${EVIDENCE_BUCKET}/cloud-build-source"`)
	requireContains(t, "scripts/mirror-public-images.sh",
		`printf 'TF_VAR_cert_manager_images=%q\n'`, "@${digest}",
		`gcloud artifacts docker images describe "$candidate"`,
		`--format='value(image_summary.digest)'`)
	requireNotContains(t, "scripts/mirror-public-images.sh", "awk '/digest: sha256:/")
}

func TestLayer04PrivateGKEContract(t *testing.T) {
	requireContains(t, "terraform/cluster/main.tf",
		"enable_private_nodes", "ip_endpoints_config", "enabled = false", "ADVANCED_DATAPATH",
		"GKE_METADATA", "enable_secure_boot", "CHANNEL_STANDARD",
		"depends_on = [google_container_cluster.lab]")
	requireContains(t, "scripts/gates/live/layer-04.sh",
		"controlPlaneEndpointsConfig.ipEndpointsConfig.enabled == false",
		"managedPrometheusConfig.enabled == true", "system-node-pool.json",
		"spot-node-pool.json", "kubectl wait --for=condition=Ready node")
	if count := strings.Count(content(t, "terraform/cluster/main.tf"), "depends_on = [google_container_cluster.lab]"); count != 3 {
		t.Errorf("all three Workload Identity binding groups must depend on cluster creation; found %d explicit dependencies", count)
	}
	requireContains(t, ".trivyignore.yaml",
		"GCP-0061", "IP endpoints disabled", "terraform/cluster/main.tf", "expired_at")
	requireContains(t, "scripts/ci/security-gates.sh",
		"--skip-dirs .terraform --skip-dirs test-results")
}

func TestLayer05AddonsSecurity(t *testing.T) {
	requireContains(t, "terraform/addons/main.tf", "config.enableGatewayAPI", "crds.enabled", "run_as_non_root")
	requireContains(t, "terraform/addons/variables.tf", "@sha256:")
}

func TestLayer06WorkloadControls(t *testing.T) {
	requireContains(t, "terraform/workloads/main.tf",
		"default-deny", "kubernetes_resource_quota_v1", "kubernetes_horizontal_pod_autoscaler_v2",
		"pod-security.kubernetes.io/enforce")
	requireContains(t, "terraform/workloads/variables.tf", "@sha256:")
}

func TestLayer07DeliverySupplyChain(t *testing.T) {
	requireContains(t, "terraform/delivery/main.tf",
		"require_approval", "REQUIRE_ATTESTATION", "ENFORCED_BLOCK_AND_AUDIT_LOG",
		"RSA_SIGN_PSS_2048_SHA256", "dns_endpoint = true")
	requireContains(t, "deploy/skaffold.yaml", "verify:", "production")
}

func TestLayer08EdgeTLSAndWAF(t *testing.T) {
	requireContains(t, "terraform/edge/main.tf",
		"nip.io", "ClusterIssuer", "RequestRedirect", "GCPBackendPolicy",
		"evaluatePreconfiguredWaf", "rate_based_ban")
}

func TestLayer09RecoveryAndTeardown(t *testing.T) {
	requireContains(t, "terraform/recovery/main.tf",
		"include_volume_data", "include_secrets", "DELETE_AND_RESTORE", "RESTORE_VOLUME_DATA_FROM_BACKUP")
	requireContains(t, "scripts/teardown-runtime.sh",
		"destroy recovery", "destroy edge", "destroy cluster", "destroy platform", "destroy network")
}
