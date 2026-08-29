# Version inventory

| Component | Constraint or baseline | Source of truth |
| --- | --- | --- |
| Terraform | 1.16.0 in Dev Container/CI; roots accept 1.15.9–1.16.x | Dev Container, workflow, `versions.tf` |
| Google provider | constraint `~> 7.45`; locked 7.46.0 | each Terraform root lockfile |
| Kubernetes provider | constraint `~> 3.2`; locked 3.2.1 | applicable root lockfile |
| Helm provider | constraint `~> 3.2`; locked 3.2.0 | addons lockfile |
| Go | 1.26.7 toolchain; module language 1.26 | Dockerfile, Dev Container, workflow, `go.mod` |
| GKE/Kubernetes | Regular release channel | live gate evidence |
| kubectl | 1.36.1 client baseline | Dev Container |
| cert-manager | 1.21.x | addons variables and Helm lock evidence |
| PostgreSQL | 18 Enterprise | platform Terraform |
| Cloud Pub/Sub Go | v2.6.2 | `app/go.mod`/`go.sum` |
| OpenTelemetry Go | v1.46.0 coordinated release; HTTP instrumentation v0.70.0 | `app/go.mod`/`go.sum` |
| Container images | immutable digest only | Terraform inputs and release evidence |
| GitHub Actions | immutable 40-character SHA | workflow files |
| upload-artifact action | v7.0.1 pinned to a full commit SHA | workflow files |
| Mermaid CLI | 11.12.0 documentation renderer | diagram render workflow |
| actionlint | 1.7.12 | security-tool installer |
| Gitleaks | 8.28.0 | security-tool installer |
| govulncheck | 1.7.0 | security-tool installer |
| Kubeconform | 0.7.0 | security-tool installer |
| TFLint / Google rules | 0.64.0 / 0.39.0 | installer and `.tflint.hcl` |
| Trivy | 0.72.0 with verified release SHA-256 | security-tool installer |

Dependabot opens controlled updates. A version change must update the relevant
manifest/lockfile, this inventory, release or migration notes, and affected tests.
The Mermaid CLI dependency currently reports an upstream Puppeteer deprecation;
it is tracked as an update item and does not affect the committed SVG output.
