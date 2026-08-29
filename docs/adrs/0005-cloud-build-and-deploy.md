# ADR 0005: Cloud Build plus Cloud Deploy

**Decision:** GitHub Actions orchestrates infrastructure gates; Cloud Build owns
trusted image construction/provenance; Cloud Deploy owns application promotion.
The division demonstrates both external CI federation and native GCP delivery
without two reconcilers managing the same Kubernetes objects.
