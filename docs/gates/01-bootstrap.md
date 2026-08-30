# Gate 01: bootstrap

Apply locally with a dedicated billing choice. Verify the project/API allowlist,
budget, deletion-resistant private state bucket, targeted audit logs,
repository-ID-bound WIF provider, four phase identities, and main-branch
workflow/environment restrictions. Policy Troubleshooter must prove the selected
allow/deny matrix, the wrong-workflow test must fail authentication, and no
user-managed service-account keys may exist. Migrate bootstrap state only after
these checks and publish the gate record.

The gate records a cumulative source digest. Later-layer-only changes can reuse
this bootstrap proof until it expires; changes to bootstrap or shared gate logic
require the live bootstrap checks to run again.
