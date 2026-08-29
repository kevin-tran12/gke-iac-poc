# Runbook: certificate pending

Inspect Certificate, Order, Challenge, solver HTTPRoute, Gateway listener and DNS
resolution. Confirm the static address matches nip.io and NetworkPolicy permits the
solver. Respect ACME rate limits; use the staging ACME server while debugging.
Destroy the edge on timeout to stop load-balancer charges.
