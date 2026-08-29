# Repository map

This repository is organized around the same bottom-up layers used by local
development, CI, live provisioning, evidence collection, and teardown.

```text
.
|-- .devcontainer/          Reproducible Terraform, Go, kubectl, and Helm tools
|-- .githooks/              Local pre-push quality gate
|-- .github/
|   |-- workflows/          Per-layer CI, protected live runs, promotion, teardown
|   `-- ISSUE_TEMPLATE/     Structured failure-lab reports
|-- app/
|   |-- cmd/                API, worker, and database migration entry points
|   |-- internal/           Pub/Sub, storage, telemetry, and HTTP implementation
|   `-- migrations/         Optional Cloud SQL schema migrations
|-- deploy/
|   |-- base/               Shared Kubernetes application resources
|   `-- overlays/           Staging, production, and optional data variants
|-- docs/
|   |-- adrs/               Architectural decisions and tradeoffs
|   |-- diagrams/           Mermaid sources and recruiter-viewable SVGs
|   |-- gates/              Layer acceptance contracts
|   |-- incidents/          Sanitized incident examples
|   |-- labs/               Failure-injection procedures
|   `-- runbooks/           Operations, recovery, rollback, and teardown
|-- evidence/               Sanitized evidence templates and generated indexes
|-- scripts/
|   |-- ci/                 Checks shared verbatim by local development and CI
|   `-- gates/              Live tests, gate recording, and prerequisite checks
|-- terraform/
|   |-- bootstrap/          Project, APIs, state, budgets, and GitHub identity
|   |-- network/            VPC, subnets, Private Google Access, optional NAT
|   |-- platform/           Artifact Registry, Pub/Sub, GCS, IAM, optional SQL
|   |-- cluster/            Private GKE and bounded Spot node pool
|   |-- addons/             cert-manager and OpenTelemetry Collector
|   |-- workloads/          Namespaces, policies, test images, and recovery fixture
|   |-- delivery/           Cloud Build, Cloud Deploy, KMS, Binary Authorization
|   |-- edge/               Gateway, TLS, Cloud Armor, DNS, and uptime checks
|   |-- recovery/           Backup for GKE plan
|   |-- modules/            Small reusable Terraform building blocks
|   `-- profiles/           Explicit cost/capability choices
`-- tests/
    |-- e2e/                Production-like public and asynchronous journeys
    |-- gates/              Terraform fixture tests
    |-- labs/               Reversible failure injection and recovery assertions
    `-- load/               HPA and abuse-control traffic generators
```

Each numbered Terraform root owns a separate state boundary. Its matching gate
must pass locally, in pull-request CI, and—when cloud resources exist—in the live
environment before the next root may run. Production promotion is intentionally
separate from infrastructure provisioning.

Generated credentials, Terraform state, plans, build outputs, raw logs, and
unsanitized evidence are ignored. Provider and Go dependency lock data are
committed because they are part of the reproducible build contract.
