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
| Cloud Pub/Sub Go | v2.6.0 | `app/go.mod`/`go.sum` |
| OpenTelemetry Go | v1.44.0 coordinated release | `app/go.mod`/`go.sum` |
| Container images | immutable digest only | Terraform inputs and release evidence |
| GitHub Actions | immutable 40-character SHA | workflow files |
| Mermaid CLI | 11.12.0 documentation renderer | diagram render workflow |

Dependabot opens controlled updates. A version change must update the relevant
manifest/lockfile, this inventory, release or migration notes, and affected tests.
The Mermaid CLI dependency currently reports an upstream Puppeteer deprecation;
it is tracked as an update item and does not affect the committed SVG output.
