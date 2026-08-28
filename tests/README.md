# End-to-end tests

Tests will verify outcomes rather than merely checking that Terraform returned
success. They may use `kubectl` for read-only inspection and controlled actions
needed by a failure test, but all persistent resources remain Terraform-owned.

The suite must cover:

- rollout and endpoint readiness;
- client-side TLS and redirect validation;
- safe header forwarding and request blocking;
- multiple backend Pod hostnames;
- HPA scale-up, readiness, and scale-down;
- optional node autoscaling; and
- teardown verification for every potentially billable resource.

Every wait must have a timeout, every load generator must have a deadline, and the
top-level runner must execute cleanup even after a failed assertion.

