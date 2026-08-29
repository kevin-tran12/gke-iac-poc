# ADR 0008: deployment ownership

**Decision:** Terraform owns infrastructure, namespaces, policies, addons and test
workloads. Cloud Deploy owns the Go application's Deployments/Services. This
prevents perpetual drift between infrastructure and release tools.
