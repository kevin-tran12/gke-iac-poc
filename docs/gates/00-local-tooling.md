# Gate 00: local tooling

Run `make validate` in the Dev Container. Pass criteria: pinned versions resolve,
Go tests/race detector pass, every Terraform root formats and validates, both
Kustomize overlays render, shell scripts pass ShellCheck, and required documents
exist. No cloud credentials are used.
