# Sample incident: failed staging rollout

An intentionally unhealthy signed image failed readiness during Cloud Deploy
verification. Promotion remained blocked and production served the prior digest.
The rollout event and readiness failures identified the condition; the operator
abandoned the rollout and re-released the last verified digest. Durable job E2E
and production health passed afterward. Corrective control: keep verification
mandatory and retain the previous digest for rollback.
