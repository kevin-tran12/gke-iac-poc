#!/usr/bin/env bash
set -euo pipefail

: "${TF_VAR_project_id:?project ID required}"
: "${REGION:=us-central1}"
: "${CLOUD_BUILD_SERVICE_ACCOUNT:?Cloud Build service account required}"
: "${GO_BUILDER_IMAGE:?digest-pinned Go builder image required}"
: "${DOCKER_BUILDER_IMAGE:?digest-pinned Docker builder image required}"
: "${RUNTIME_IMAGE:?digest-pinned runtime image required}"
: "${SYFT_IMAGE:?digest-pinned Syft image required}"
: "${SMOKE_IMAGE:?digest-pinned curl image required}"
: "${VERIFIER_IMAGE:?digest-pinned kubectl image required}"
: "${EVIDENCE_BUCKET:?evidence bucket required}"
: "${BINAUTHZ_ATTESTOR:?Binary Authorization attestor name required}"
: "${ATTESTATION_KEY_VERSION:?KMS attestation key version required}"
registry="${REGION}-docker.pkg.dev/${TF_VAR_project_id}/gke-lab-containers"
mkdir -p test-results/live
build_result=test-results/live/cloud-build.json
gcloud builds submit --config cloudbuild.yaml \
	--project="$TF_VAR_project_id" \
	--service-account="projects/${TF_VAR_project_id}/serviceAccounts/${CLOUD_BUILD_SERVICE_ACCOUNT}" \
	--substitutions="_REGISTRY=${registry},_GO_BUILDER_IMAGE=${GO_BUILDER_IMAGE},_DOCKER_BUILDER_IMAGE=${DOCKER_BUILDER_IMAGE},_RUNTIME_IMAGE=${RUNTIME_IMAGE},_SYFT_IMAGE=${SYFT_IMAGE},_EVIDENCE_BUCKET=${EVIDENCE_BUCKET}" \
	--format=json >"$build_result"

artifact_for() {
	local component=$1
	jq -er --arg suffix "/gke-lab-${component}:" '
		.results.images[]
		| select(.name | contains($suffix))
		| ((.name | sub(":[^/:]+$"; "")) + "@" + .digest)' "$build_result"
}

api_image=$(artifact_for api)
worker_image=$(artifact_for worker)
migrate_image=$(artifact_for migrate)

for image in "$api_image" "$worker_image" "$migrate_image"; do
	gcloud beta container binauthz attestations sign-and-create \
		--project="$TF_VAR_project_id" \
		--artifact-url="$image" \
		--attestor="$BINAUTHZ_ATTESTOR" \
		--attestor-project="$TF_VAR_project_id" \
		--keyversion="$ATTESTATION_KEY_VERSION"
done

release="commit-$(git rev-parse --short=12 HEAD)"
gcloud deploy releases create "$release" \
	--project="$TF_VAR_project_id" \
	--region="$REGION" \
	--delivery-pipeline=gke-lab \
	--skaffold-file=deploy/skaffold.yaml \
	--images="gke-lab-api=${api_image},gke-lab-worker=${worker_image},gke-lab-smoke=${SMOKE_IMAGE},gke-lab-verifier=${VERIFIER_IMAGE}"

rollout=""
for _ in {1..24}; do
	rollout=$(gcloud deploy rollouts list \
		--project="$TF_VAR_project_id" \
		--region="$REGION" \
		--delivery-pipeline=gke-lab \
		--release="$release" \
		--format='value(name)' --limit=1)
	[[ -n "$rollout" ]] && break
	sleep 5
done
test -n "$rollout"

deadline=$((SECONDS+1200))
while (( SECONDS < deadline )); do
	state=$(gcloud deploy rollouts describe "$rollout" \
		--project="$TF_VAR_project_id" \
		--region="$REGION" \
		--delivery-pipeline=gke-lab \
		--release="$release" \
		--format='value(state)')
	case "$state" in
		SUCCEEDED) break ;;
		FAILED|HALTED|CANCELLED) printf 'staging rollout ended in %s\n' "$state" >&2; exit 1 ;;
	esac
	sleep 15
done
test "${state:-}" = SUCCEEDED

jq -n \
	--arg release "$release" \
	--arg api_image "$api_image" \
	--arg worker_image "$worker_image" \
	--arg migrate_image "$migrate_image" \
	--arg staging_rollout "$rollout" \
	'{release:$release,staging_rollout:$staging_rollout,images:{api:$api_image,worker:$worker_image,migrate:$migrate_image}}' \
	>test-results/live/release.json
