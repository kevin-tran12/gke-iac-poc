# Continuous integration strategy

CI is part of each layer's implementation. A layer is not complete if its local
gate and pull-request workflow lack static checks, gate tests, negative tests,
cleanup checks, documentation, and evidence expectations.

`scripts/ci/test-layer.sh` is the single source for local and GitHub checks.
Developers run it through `make test-layer`; the version-controlled pre-push hook
runs all layers; each reusable workflow calls the same script. The Dev Container
provides the pinned Linux toolchain needed for race detection and ShellCheck.

Pull-request workflows are read-only. They use pinned actions and run Go tests,
Terraform init without a backend, validate/test, manifest rendering, ShellCheck,
and documentation checks. The aggregate `ci/all-required` check protects `main`.

Live integration runs after merge or manual dispatch. It receives short-lived GCP
credentials through GitHub OIDC, locks one environment at a time, executes only
the selected Terraform layer, executes that layer's live acceptance test, and
publishes a gate record only on success. Protected environments approve public
edge, production, paid, destructive, reaper, and final-delete operations.

Cloud Build becomes the trusted build engine only after its own layer passes.
Cloud Deploy becomes the release engine only after internal workloads pass.
Binary Authorization enforcement is enabled only after a signed staging image is
verified, preventing a policy bootstrap lockout.
