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
		`"attribute.workflow_ref"`, "local.apply_workflow_refs", "@refs/heads/main",
		`"billingbudgets.googleapis.com"`, "depends_on = [google_project_service.required]")
	requireContains(t, "terraform/bootstrap/versions.tf",
		`alias                 = "billing"`, "billing_project       = var.project_id",
		"user_project_override = true")
	requireContains(t, "scripts/gates/common.sh",
		`TF_VAR_project_id="$(state_output bootstrap project_id)"`,
		`TF_STATE_BUCKET="$(state_output bootstrap state_bucket)"`,
		"refresh_bootstrap_outputs")
	requireContains(t, "scripts/gates/live/layer-01.sh",
		"bootstrap-project.json", "billingbudgets.googleapis.com",
		"bootstrap-state-bucket.json", ".uniform_bucket_level_access == true",
		`.public_access_prevention == "enforced"`, "--managed-by=user")
	requireNotContains(t, "terraform/bootstrap/main.tf",
		"google_service_account_key", `"roles/secretmanager.secretAccessor"`,
		`"roles/cloudkms.signerVerifier"`)
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
		"private_ip_google_access = true", "secondary_ip_range", "log_config", "var.enable_nat ? 1 : 0")
	requireContains(t, "terraform/network/variables.tf", "10.10.0.0/20", "10.20.0.0/16", "10.30.0.0/20")
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
		"GKE_METADATA", "enable_secure_boot", "CHANNEL_STANDARD")
	requireContains(t, "scripts/gates/live/layer-04.sh",
		"controlPlaneEndpointsConfig.ipEndpointsConfig.enabled == false",
		"managedPrometheusConfig.enabled == true", "system-node-pool.json",
		"spot-node-pool.json", "kubectl wait --for=condition=Ready node")
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
