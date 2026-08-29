# Tests

`gates/` verifies each architectural contract before the next Terraform root is
eligible. `e2e/` exercises the real HTTPS API through GKE and asserts durable job
completion. `load/` contains bounded k6 scenarios. `labs/` temporarily injects
failures and always installs a recovery trap before mutating live state.

Live tests require explicit environment variables and otherwise skip. Every wait
has a timeout, load is capped, and all temporary mutations are reconciled back to
Terraform-owned state.

