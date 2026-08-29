# Runbook: failed Terraform apply

Stop downstream gates. Save the plan, state serial and provider error. Inspect
state and cloud inventory read-only; do not force-unlock until the owning run is
confirmed dead. Fix configuration and retry the same root. If partial resources
are unsafe or billable, destroy only that root, then run independent inventory.
