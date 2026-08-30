# Continuous integration strategy

CI is part of each layer's implementation. A layer is not complete if its local
gate and pull-request workflow lack static checks, gate tests, negative tests,
cleanup checks, documentation, and evidence expectations.

`scripts/ci/test-layer.sh` is the single source for local and GitHub layer checks,
and `scripts/ci/security-gates.sh` is the shared security gate.
Developers run it through `make test-layer`; the version-controlled pre-push hook
runs all layers; each reusable workflow calls the same script. The Dev Container
provides the pinned Linux toolchain needed for race detection and ShellCheck.

Pull-request workflows are read-only. They use pinned actions and run Go tests,
Terraform init without a backend, validate/test, manifest rendering, ShellCheck,
documentation checks, Actionlint, immutable action-reference enforcement,
Gitleaks, govulncheck, TFLint with Google rules, Kubeconform, and Trivy IaC
scanning. GitHub-managed CodeQL default setup separately scans Actions, Go, and
JavaScript/TypeScript. A pinned dependency-review job rejects new high-severity
dependency risk. The aggregate `ci/all-required` check protects `main`.

The pull-request workflow uses a fan-out/fan-in topology. Security and layer 00
run first as shared prerequisites. After both succeed, static checks for layers
01 through 09 run independently in parallel, and `ci/all-required` combines
their results into one branch-protection check. Local `make test-all` remains
sequential for readable output and predictable failure diagnosis.

Live integration runs after merge or manual dispatch. Plan, apply, and verify are
separate operations. The private state bucket holds the short-lived saved plan;
GitHub artifacts never contain raw Terraform plan files. Apply rejects a changed
commit, source digest, input digest, profile, expired plan, or mismatched plan
digest. Verification runs the live contract plus a no-drift plan before publishing
the canonical `verified` gate. Protected environments approve apply, public edge,
production, paid, destructive, reaper, and final-delete operations.

The reusable live workflow selects one of four service accounts from the layer
number: foundation (1–3), cluster (4–6), delivery (7–8), or recovery (9). WIF
also validates the immutable repository and owner IDs, `main`, the caller and
reusable workflow refs, and the job environment. Repository variables alone
cannot widen that trust policy.

Gate records use explicit `planned`, `applied`, `verified`, `failed`, and
`destroyed` states. A four-hour environment lease is created before the first
runtime apply and later layers cannot extend it. The hourly reaper follows that
lease rather than deriving lifetime from the latest passing gate.

Cloud Build becomes the trusted build engine only after its own layer passes.
Cloud Deploy becomes the release engine only after internal workloads pass.
Binary Authorization enforcement is enabled only after a signed staging image is
verified, preventing a policy bootstrap lockout.
