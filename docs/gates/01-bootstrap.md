# Gate 01: bootstrap

Apply locally with a dedicated billing choice. Verify the project/API allowlist,
budget, versioned private state bucket, repository-ID-bound WIF provider, separate
plan/apply identities, main-branch workflow allowlisting for apply impersonation,
and absence of service-account keys or Terraform access to secret payloads. Migrate
bootstrap state only after these checks and publish the gate record.

The gate records a cumulative source digest. Later-layer-only changes can reuse
this bootstrap proof until it expires; changes to bootstrap or shared gate logic
require the live bootstrap checks to run again.
